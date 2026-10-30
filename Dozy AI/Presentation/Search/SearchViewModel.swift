//
//  SearchViewModel.swift
//  Dozy AI
//
//  검색 화면 ViewModel (#72). 키워드 검색(SearchMatcher) 위에 자연어 질의(기간 · 집계)를 얹는다.
//  - 입력 중에는 키워드 결과를 바로 보여 주고, 0.8초 멈추거나 return 키를 누르면 한 번만 해석한다 (키 입력마다 모델 호출 금지)
//  - 해석에 기간이 있으면 기간 검색 결과 + 집계 카드, 없으면 기존 키워드 검색 그대로 (해석 실패 폴백이 자동)
//
//  Dozy 일정 · 일지 · 카테고리는 View 의 `@Query` 를 그대로 받는다 — 상세 · 편집 시트에서 고친 내용이
//  저장 즉시 결과에 반영되는 기존 동작을 유지하기 위해서다.
//

import Foundation
import Combine
import WidgetKit
import OSLog

@MainActor
final class SearchViewModel: ObservableObject {

    // MARK: - 상태

    @Published var query: String = ""
    @Published private(set) var externalEvents: [CalendarEvent] = []
    @Published private(set) var isLoadingExternal = false

    @Published var selectedEvent: CalendarEvent?
    @Published var dozyEventToEdit: DozyEvent?
    @Published var calendarEventToEdit: CalendarEvent?
    @Published var pendingMemoDelete: PendingMemoDelete?
    /// 일정 수정 · 표시 설정 결과 토스트 (#143)
    @Published var toast: DozyToast?

    /// 기간이 있는 해석 결과. nil 이면 키워드 검색.
    @Published private(set) var interpretation: SearchInterpretation?
    /// 해석 대기 · 진행 중 (빈 결과 대신 진행 표시를 보여 주기 위해)
    @Published private(set) var isInterpreting = false
    /// 기간 칩을 지웠을 때 — 원문 대신 해석된 키워드로 키워드 검색
    @Published private(set) var keywordOverride: String?

    /// 사용자 카테고리 이름 (View 의 @Query 가 넘겨준다). 해석기가 카테고리 힌트를 고를 때 쓴다.
    var categoryNames: [String] = []

    var hasQuery: Bool { !SearchMatcher.normalize(query).isEmpty }

    /// 메모 스니펫 · 키워드 결과에 쓸 검색어
    var effectiveKeyword: String {
        if let interpretation { return interpretation.intent.keyword ?? "" }
        return keywordOverride ?? query
    }

    // MARK: - 의존성

    private let fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let updateCalendarEventUseCase: UpdateCalendarEventUseCase
    private let saveEventDisplaySettingsUseCase: SaveEventDisplaySettingsUseCase
    private let saveWorkLogUseCase: SaveWorkLogUseCase
    private let parseSearchQueryUseCase: ParseSearchQueryUseCase
    private let searchEventsUseCase: SearchEventsUseCase
    private let now: () -> Date

    private var hasLoadedExternal = false
    private var cancellables = Set<AnyCancellable>()
    private var interpretTask: Task<Void, Never>?
    private var searchCancellable: AnyCancellable?
    /// return 키와 디바운스가 같은 문장을 두 번 해석하지 않게
    private var lastInterpretedText: String?

    init(
        fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase,
        updateDozyEventUseCase: UpdateDozyEventUseCase,
        updateCalendarEventUseCase: UpdateCalendarEventUseCase,
        saveEventDisplaySettingsUseCase: SaveEventDisplaySettingsUseCase,
        saveWorkLogUseCase: SaveWorkLogUseCase,
        parseSearchQueryUseCase: ParseSearchQueryUseCase,
        searchEventsUseCase: SearchEventsUseCase,
        debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(800),
        now: @escaping () -> Date = Date.init
    ) {
        self.fetchCalendarEventsForPeriodUseCase = fetchCalendarEventsForPeriodUseCase
        self.updateDozyEventUseCase = updateDozyEventUseCase
        self.updateCalendarEventUseCase = updateCalendarEventUseCase
        self.saveEventDisplaySettingsUseCase = saveEventDisplaySettingsUseCase
        self.saveWorkLogUseCase = saveWorkLogUseCase
        self.parseSearchQueryUseCase = parseSearchQueryUseCase
        self.searchEventsUseCase = searchEventsUseCase
        self.now = now

        // 외부 일정은 화면을 열 때가 아니라 첫 검색어가 들어올 때 한 번 불러온다
        $query
            .filter { !SearchMatcher.normalize($0).isEmpty }
            .first()
            .sink { [weak self] _ in self?.loadExternalEventsIfNeeded() }
            .store(in: &cancellables)

        // 입력이 바뀌면 이전 해석은 버리고 키워드 결과로 돌아간다
        $query
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] text in self?.resetInterpretation(for: text) }
            .store(in: &cancellables)

        // 입력이 멈추면 한 번 해석
        $query
            .dropFirst()
            .removeDuplicates()
            .debounce(for: debounce, scheduler: DispatchQueue.main)
            .sink { [weak self] text in self?.interpret(text) }
            .store(in: &cancellables)
    }

    convenience init(container: DependencyContainer) {
        self.init(
            fetchCalendarEventsForPeriodUseCase: container.fetchCalendarEventsForPeriodUseCase,
            updateDozyEventUseCase: container.updateDozyEventUseCase,
            updateCalendarEventUseCase: container.updateCalendarEventUseCase,
            saveEventDisplaySettingsUseCase: container.saveEventDisplaySettingsUseCase,
            saveWorkLogUseCase: container.saveWorkLogUseCase,
            parseSearchQueryUseCase: container.parseSearchQueryUseCase,
            searchEventsUseCase: container.searchEventsUseCase
        )
    }

    // MARK: - 결과

    /// 기간 해석이 있으면 기간 검색 결과(일정만), 없으면 키워드 검색.
    func results(dozyEvents: [DozyEvent], workLogs: [WorkLog], categories: [UserCategory]) -> SearchResults {
        if let interpretation {
            return SearchResults(events: interpretation.result?.events ?? [])
        }
        return SearchMatcher.match(
            query: keywordOverride ?? query,
            dozyEvents: dozyEvents,
            externalEvents: externalEvents,
            workLogs: workLogs,
            categories: categories
        )
    }

    func matchedMemo(for event: CalendarEvent, dozyEvent: DozyEvent?) -> String? {
        SearchMatcher.matchedMemo(for: event, dozyEvent: dozyEvent, query: effectiveKeyword)
    }

    func matchedMemos(in log: WorkLog) -> [String] {
        SearchMatcher.matchedMemos(in: log, query: effectiveKeyword)
    }

    // MARK: - 자연어 질의

    /// return 키 — 디바운스를 기다리지 않고 바로 해석
    func submitNow() {
        interpret(query)
    }

    /// 기간 칩 지우기 → 해석된 키워드로 키워드 검색 (집계도 함께 사라진다)
    func removePeriod() {
        guard let intent = interpretation?.intent else { return }
        cancelInterpretation()
        keywordOverride = intent.keyword ?? ""
    }

    /// 카테고리 칩 지우기 → 제목 · 장소 · 메모 매칭만으로 다시 검색
    func removeCategory() {
        guard var intent = interpretation?.intent, intent.categoryHint != nil else { return }
        intent.categoryHint = nil
        runPeriodSearch(intent)
    }

    private func resetInterpretation(for text: String) {
        cancelInterpretation()
        keywordOverride = nil
        lastInterpretedText = nil
        // 여러 단어면 곧 해석이 붙을 수 있으니 "결과 없음" 대신 진행 표시
        isInterpreting = QueryRuleParser.isMultiWord(text)
            || QueryRuleParser.findPeriod(in: text.lowercased(), referenceDate: now(), calendar: .mondayFirst()) != nil
    }

    private func cancelInterpretation() {
        interpretTask?.cancel()
        interpretTask = nil
        searchCancellable = nil
        interpretation = nil
        isInterpreting = false
    }

    private func interpret(_ text: String) {
        guard !SearchMatcher.normalize(text).isEmpty else {
            cancelInterpretation()
            return
        }
        guard text != lastInterpretedText else { return }
        lastInterpretedText = text
        interpretTask?.cancel()
        isInterpreting = true
        let categories = categoryNames
        let reference = now()
        interpretTask = Task { [weak self] in
            guard let self else { return }
            let intent = await self.parseSearchQueryUseCase.execute(text: text, referenceDate: reference, categories: categories)
            guard !Task.isCancelled, self.query == text else { return }
            guard intent.period != nil else {
                // 기간이 없으면 기존 키워드 검색 — 원문 그대로 (회귀 없음)
                self.interpretation = nil
                self.isInterpreting = false
                return
            }
            self.runPeriodSearch(intent)
        }
    }

    private func runPeriodSearch(_ intent: SearchQueryIntent) {
        isInterpreting = true
        interpretation = SearchInterpretation(intent: intent, result: interpretation?.result)
        searchCancellable = searchEventsUseCase.execute(intent)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case .failure = completion {
                        self.interpretation?.result = SearchPeriodResult(events: [], aggregate: nil)
                    }
                    self.isInterpreting = false
                },
                receiveValue: { [weak self] result in
                    guard let self, self.interpretation?.intent == intent else { return }
                    self.interpretation?.result = result
                    self.isInterpreting = false
                }
            )
    }

    /// 편집 · 삭제 뒤 기간 검색 결과를 다시 계산 — 기간 결과는 @Query 가 아니라 조회 스냅샷이다.
    private func refreshInterpretation() {
        guard let intent = interpretation?.intent else { return }
        runPeriodSearch(intent)
    }

    // MARK: - 외부 일정

    /// 오래된 기록 검색 지원 — 과거 10년 / 미래 2년. Dozy 소스는 @Query 로 따로 받으므로 제외.
    func loadExternalEventsIfNeeded() {
        guard !hasLoadedExternal else { return }
        fetchExternalEvents()
    }

    private func fetchExternalEvents(onLoaded: (() -> Void)? = nil) {
        guard !isLoadingExternal else { return }
        isLoadingExternal = true
        let cal = Calendar.current
        let today = now()
        let end = cal.date(byAdding: .year, value: 2, to: today) ?? today
        let start = cal.date(byAdding: .year, value: -10, to: today) ?? today
        fetchCalendarEventsForPeriodUseCase.execute(from: start, to: end)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in self?.isLoadingExternal = false },
                receiveValue: { [weak self] events in
                    guard let self else { return }
                    self.externalEvents = events.filter { $0.source != .dozy }
                    self.hasLoadedExternal = true
                    self.isLoadingExternal = false
                    onLoaded?()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 저장

    /// Dozy 일정 저장. 목록은 @Query 가 갱신하지만 상세 시트는 열 때 받은 값 스냅샷이라 직접 바꿔 준다.
    /// - successToast: 성공 토스트 (#143). 메모 저장 · 삭제처럼 따로 알릴 필요 없는 저장은 nil.
    /// - failureToast: 실패 토스트 — 실패는 항상 알린다. 메모 저장은 `.memoSaveFailed` (#144).
    func save(_ dozy: DozyEvent, successToast: DozyToast? = .eventUpdated, failureToast: DozyToast = .eventUpdateFailed) {
        updateDozyEventUseCase.execute(dozy)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.reportFailure(error, context: "search.event.update", toast: failureToast)
                }
            }, receiveValue: { [weak self] in
                guard let self else { return }
                if let successToast { self.toast = successToast }
                if self.selectedEvent?.id == dozy.id {
                    self.selectedEvent = dozy.toCalendarEvent()
                }
                self.refreshInterpretation()
                self.notifyEventChanged()
            })
            .store(in: &cancellables)
    }

    /// Apple · Google 일정 수정. 외부 목록을 다시 불러온 뒤 상세 시트도 새 값으로 바꾼다.
    func saveCalendarEdit(_ event: CalendarEvent, with edit: CalendarEventEditRequest) {
        updateCalendarEventUseCase.execute(event, with: edit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.reportFailure(error, context: "search.event.update_external", toast: .eventUpdateFailed)
                }
            }, receiveValue: { [weak self] in
                guard let self else { return }
                self.toast = .eventUpdated
                self.fetchExternalEvents { [weak self] in
                    guard let self, self.selectedEvent?.id == event.id else { return }
                    self.selectedEvent = Self.refreshed(event, in: self.externalEvents) ?? self.selectedEvent
                }
                self.refreshInterpretation()
                self.notifyEventChanged()
            })
            .store(in: &cancellables)
    }

    /// 같은 id 중 원래 시작 시각에 가장 가까운 것 — 반복 일정은 occurrence 마다 id 가 같다.
    static func refreshed(_ event: CalendarEvent, in events: [CalendarEvent]) -> CalendarEvent? {
        events
            .filter { $0.id == event.id }
            .min(by: { abs($0.startDate.timeIntervalSince(event.startDate)) < abs($1.startDate.timeIntervalSince(event.startDate)) })
    }

    /// 수정 실패 — 토스트 + 로그 + Crashlytics 비치명 기록 (#143)
    private func reportFailure(_ error: DozyError, context: String, toast failureToast: DozyToast) {
        Logger.search.error("\(context, privacy: .public) 실패: \(error.localizedDescription, privacy: .public)")
        CrashReporting.record(error, context: context)
        toast = failureToast
    }

    /// 홈(오늘 캐시) · 위젯 갱신 — 캘린더 화면 저장 경로와 같은 신호.
    private func notifyEventChanged() {
        NotificationCenter.default.post(name: .dozyEventChanged, object: nil)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 상세 화면의 우선순위 · 고정 · 카테고리 저장. Dozy 는 모델에, 외부 일정은 표시 설정 저장소에.
    func applyDisplaySettings(
        event: CalendarEvent, priority: Int, isPinned: Bool, category: String?,
        dozyEvents: [DozyEvent], categories: [UserCategory]
    ) {
        if event.source == .dozy {
            guard let dozy = dozyEvents.first(where: { $0.id == event.id }) else { return }
            dozy.priority = priority
            dozy.isPinned = isPinned
            if let category {
                dozy.category = category
                if let cat = categories.first(where: { $0.name == category }) {
                    dozy.colorHex = cat.colorHex
                }
            }
            save(dozy, successToast: .displaySettingsSaved)
        } else {
            saveEventDisplaySettingsUseCase
                .execute(eventID: event.id, priority: priority, isPinned: isPinned,
                         category: category ?? event.category)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                    self?.toast = .displaySettingsSaved
                })
                .store(in: &cancellables)
        }
    }

    // MARK: - 메모 삭제

    func requestMemoDelete(_ memo: String, from parent: PendingMemoDelete.Parent) {
        pendingMemoDelete = PendingMemoDelete(parent: parent, memo: memo)
    }

    func confirmMemoDelete() {
        guard let pending = pendingMemoDelete else { return }
        pendingMemoDelete = nil
        switch pending.parent {
        case .dozyEvent(let dozy):
            dozy.memos.removeAll { $0 == pending.memo }
            dozy.updatedAt = now()
            save(dozy, successToast: nil, failureToast: .memoDeleteFailed)
        case .workLog(let log):
            guard let idx = log.memos.firstIndex(of: pending.memo) else { return }
            saveWorkLogUseCase.deleteMemo(at: idx, in: log)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.reportFailure(error, context: "search.memo.delete", toast: .memoDeleteFailed)
                    }
                }, receiveValue: { })
                .store(in: &cancellables)
        }
    }

    // MARK: - 백그라운드

    /// 이전엔 .inactive 에서도 모달 상태를 지웠는데, iOS 가 sheet 프레젠테이션 / 키보드 dismiss 시
    /// scenePhase 를 일시적으로 .inactive 로 떨어뜨리는 경우가 있어 검색 결과 탭 → 상세 sheet 가
    /// 떴다가 즉시 dismiss 되는 버그를 만들었음. 진짜 백그라운드(.background)로 갈 때만 정리한다 —
    /// privacy 오버레이는 PrivacyScreenManager 가 .inactive 에 별도 처리.
    func clearModalState() {
        selectedEvent = nil
        dozyEventToEdit = nil
        calendarEventToEdit = nil
        pendingMemoDelete = nil
    }
}

/// 기간이 있는 해석과 그 검색 결과. result 가 nil 이면 조회 중.
struct SearchInterpretation: Equatable {
    var intent: SearchQueryIntent
    var result: SearchPeriodResult?
}

/// 삭제 확인용 — 이벤트 메모 or 일지 메모
struct PendingMemoDelete {
    enum Parent {
        case dozyEvent(DozyEvent)
        case workLog(WorkLog)
    }
    let parent: Parent
    let memo: String
}
