//
//  SearchViewModel.swift
//  Dozy AI
//
//  검색 화면 ViewModel (#72 선행 리팩터링). SearchView 가 직접 하던 외부 일정 조회 · 저장 · 메모 삭제 ·
//  표시 설정 저장을 UseCase 로 옮겼다. 매칭 자체는 순수 계산 `SearchMatcher`.
//
//  Dozy 일정 · 일지 · 카테고리는 View 의 `@Query` 를 그대로 받는다 — 상세 · 편집 시트에서 고친 내용이
//  저장 즉시 결과에 반영되는 기존 동작을 유지하기 위해서다.
//

import Foundation
import Combine
import WidgetKit

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

    var hasQuery: Bool { !SearchMatcher.normalize(query).isEmpty }

    // MARK: - 의존성

    private let fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let updateCalendarEventUseCase: UpdateCalendarEventUseCase
    private let saveEventDisplaySettingsUseCase: SaveEventDisplaySettingsUseCase
    private let saveWorkLogUseCase: SaveWorkLogUseCase
    private let now: () -> Date

    private var hasLoadedExternal = false
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase,
        updateDozyEventUseCase: UpdateDozyEventUseCase,
        updateCalendarEventUseCase: UpdateCalendarEventUseCase,
        saveEventDisplaySettingsUseCase: SaveEventDisplaySettingsUseCase,
        saveWorkLogUseCase: SaveWorkLogUseCase,
        now: @escaping () -> Date = Date.init
    ) {
        self.fetchCalendarEventsForPeriodUseCase = fetchCalendarEventsForPeriodUseCase
        self.updateDozyEventUseCase = updateDozyEventUseCase
        self.updateCalendarEventUseCase = updateCalendarEventUseCase
        self.saveEventDisplaySettingsUseCase = saveEventDisplaySettingsUseCase
        self.saveWorkLogUseCase = saveWorkLogUseCase
        self.now = now

        // 외부 일정은 화면을 열 때가 아니라 첫 검색어가 들어올 때 한 번 불러온다
        $query
            .filter { !SearchMatcher.normalize($0).isEmpty }
            .first()
            .sink { [weak self] _ in self?.loadExternalEventsIfNeeded() }
            .store(in: &cancellables)
    }

    convenience init(container: DependencyContainer) {
        self.init(
            fetchCalendarEventsForPeriodUseCase: container.fetchCalendarEventsForPeriodUseCase,
            updateDozyEventUseCase: container.updateDozyEventUseCase,
            updateCalendarEventUseCase: container.updateCalendarEventUseCase,
            saveEventDisplaySettingsUseCase: container.saveEventDisplaySettingsUseCase,
            saveWorkLogUseCase: container.saveWorkLogUseCase
        )
    }

    // MARK: - 결과

    func results(dozyEvents: [DozyEvent], workLogs: [WorkLog], categories: [UserCategory]) -> SearchResults {
        SearchMatcher.match(
            query: query,
            dozyEvents: dozyEvents,
            externalEvents: externalEvents,
            workLogs: workLogs,
            categories: categories
        )
    }

    func matchedMemo(for event: CalendarEvent, dozyEvent: DozyEvent?) -> String? {
        SearchMatcher.matchedMemo(for: event, dozyEvent: dozyEvent, query: query)
    }

    func matchedMemos(in log: WorkLog) -> [String] {
        SearchMatcher.matchedMemos(in: log, query: query)
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
    func save(_ dozy: DozyEvent) {
        updateDozyEventUseCase.execute(dozy)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                if self.selectedEvent?.id == dozy.id {
                    self.selectedEvent = dozy.toCalendarEvent()
                }
                self.notifyEventChanged()
            })
            .store(in: &cancellables)
    }

    /// Apple · Google 일정 수정. 외부 목록을 다시 불러온 뒤 상세 시트도 새 값으로 바꾼다.
    func saveCalendarEdit(_ event: CalendarEvent, with edit: CalendarEventEditRequest) {
        updateCalendarEventUseCase.execute(event, with: edit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.fetchExternalEvents { [weak self] in
                    guard let self, self.selectedEvent?.id == event.id else { return }
                    self.selectedEvent = Self.refreshed(event, in: self.externalEvents) ?? self.selectedEvent
                }
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
            save(dozy)
        } else {
            saveEventDisplaySettingsUseCase
                .execute(eventID: event.id, priority: priority, isPinned: isPinned,
                         category: category ?? event.category)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
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
            save(dozy)
        case .workLog(let log):
            guard let idx = log.memos.firstIndex(of: pending.memo) else { return }
            saveWorkLogUseCase.deleteMemo(at: idx, in: log)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { })
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

/// 삭제 확인용 — 이벤트 메모 or 일지 메모
struct PendingMemoDelete {
    enum Parent {
        case dozyEvent(DozyEvent)
        case workLog(WorkLog)
    }
    let parent: Parent
    let memo: String
}
