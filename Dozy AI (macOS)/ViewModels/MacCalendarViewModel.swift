//
//  MacCalendarViewModel.swift
//  Dozy AI (macOS)
//
//  M4.5 — 월별 캘린더 뷰 전용 ViewModel.
//  성능 최적화: 범위 캐시 + 인접 prefetch(±2) + wide prewarm(±3) +
//  eventsByDate union merge + buildEventsByDate 최적화.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class MacCalendarViewModel: ObservableObject {

    // MARK: - Published

    @Published var currentMonth: Date = Date()
    @Published var selectedDate: Date = Date()
    @Published var viewMode: MacCalendarViewMode = .month
    /// 월 이동 방향 — 1: 다음, -1: 이전, 0: 초기/무방향.
    @Published var monthTransitionDirection: Int = 0
    /// 모든 로드된 범위의 union — 월 전환 시 사라졌다 나타나는 현상 방지.
    @Published var eventsByDate: [Date: [CalendarEvent]] = [:]
    @Published var dozyEventsByID: [String: DozyEvent] = [:]
    @Published var completionsByID: [String: Bool] = [:]
    @Published var mySharedCalendars: [SharedCalendar] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Cache (range key → fetched data)

    private var cachedEventsByDate:   [String: [Date: [CalendarEvent]]] = [:]
    private var cachedDozyEventsByID: [String: [String: DozyEvent]]     = [:]
    private var cachedCompletions:    [String: [String: Bool]]          = [:]
    private var loadedRangeKeys:      Set<String> = []
    private var inflightRangeKeys:    Set<String> = []

    // MARK: - Deps

    private let fetchDozyEventsForPeriodUseCase: FetchDozyEventsForPeriodUseCase
    private let fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase
    private let fetchEventCompletionsForPeriodUseCase: FetchEventCompletionsForPeriodUseCase
    private let createDozyEventUseCase: CreateDozyEventUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let deleteDozyEventUseCase: DeleteDozyEventUseCase
    private let toggleDozyEventCompletionUseCase: ToggleDozyEventCompletionUseCase
    private let toggleCalendarEventCompletionUseCase: ToggleCalendarEventCompletionUseCase
    private let sharedCalendarService: SharedCalendarServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed

    var eventsForSelectedDate: [CalendarEvent] {
        eventsByDate[Calendar.current.startOfDay(for: selectedDate)] ?? []
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        switch viewMode {
        case .month: f.dateFormat = "yyyy년 M월"
        case .week:
            let weekStart = Self.startOfWeek(for: currentMonth)
            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            f.dateFormat = "M월 d일"
            return "\(f.string(from: weekStart)) - \(f.string(from: weekEnd))"
        case .day:
            f.dateFormat = "yyyy년 M월 d일 EEEE"
        }
        return f.string(from: currentMonth)
    }

    var selectedDateTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: selectedDate)
    }

    // MARK: - Init

    init(container: DependencyContainer) {
        self.fetchDozyEventsForPeriodUseCase = container.fetchDozyEventsForPeriodUseCase
        self.fetchCalendarEventsForPeriodUseCase = container.fetchCalendarEventsForPeriodUseCase
        self.fetchEventCompletionsForPeriodUseCase = container.fetchEventCompletionsForPeriodUseCase
        self.createDozyEventUseCase = container.createDozyEventUseCase
        self.updateDozyEventUseCase = container.updateDozyEventUseCase
        self.deleteDozyEventUseCase = container.deleteDozyEventUseCase
        self.toggleDozyEventCompletionUseCase = container.toggleDozyEventCompletionUseCase
        self.toggleCalendarEventCompletionUseCase = container.toggleCalendarEventCompletionUseCase
        self.sharedCalendarService = container.sharedCalendarService

        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidateCache()
                self?.loadEventsForCurrentMonth(force: true)
            }
            .store(in: &cancellables)

        // 일정 토글 같은 가벼운 변경은 캘린더 이벤트 자체는 안 바뀌고 completion 상태만 바뀜.
        // → 전체 cache invalidate 대신 현재 보이는 범위의 completion 만 재조회.
        // 자기-트리거는 무시 — optimistic 값을 race 로 덮어쓰는 현상 방지.
        NotificationCenter.default.publisher(for: .dozyEventChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                if (note.object as AnyObject?) === self { return }
                self.refreshCompletionsOnly()
            }
            .store(in: &cancellables)

        // 다른 화면(Today / MenuBar)에서 일정을 만들거나 지웠을 때 — 리스트 자체가
        // 바뀌었으므로 전체 캐시 무효화 후 재로드. 자기-트리거는 무시.
        NotificationCenter.default.publisher(for: .dozyEventListChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                if (note.object as AnyObject?) === self { return }
                self.invalidateCache()
                self.loadEventsForCurrentMonth(force: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .dozyRequestGoToToday)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.goToToday() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .dozyRequestPreviousPeriod)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.goToPreviousMonth() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .dozyRequestNextPeriod)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.goToNextMonth() }
            .store(in: &cancellables)

        // 설정 화면에서 공유 캘린더를 만들거나 나간 직후 picker 가 stale 되지 않도록.
        NotificationCenter.default.publisher(for: .dozySharedCalendarsChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadMySharedCalendars() }
            .store(in: &cancellables)
    }

    /// 현재 보이는 범위의 EventCompletion 만 재조회. `.dozyEventChanged` 핸들러 — Apple/Dozy 이벤트
    /// 자체는 EventKit / SwiftData 에서 다시 안 가져와서 비용 거의 0.
    private func refreshCompletionsOnly() {
        let (start, end) = currentVisibleRange()
        let key = rangeKey(for: viewMode, anchor: currentMonth)
        loadCompletions(for: start, to: end, key: key, isPrefetch: false)
    }

    // MARK: - Navigation

    func goToPreviousMonth() {
        let cal = Calendar.current
        let (delta, value): (Calendar.Component, Int) = {
            switch viewMode {
            case .month: return (.month, -1)
            case .week:  return (.weekOfYear, -1)
            case .day:   return (.day, -1)
            }
        }()
        if let prev = cal.date(byAdding: delta, value: value, to: currentMonth) {
            monthTransitionDirection = -1
            currentMonth = prev
            loadEventsForCurrentMonth()
        }
    }

    func goToNextMonth() {
        let cal = Calendar.current
        let (delta, value): (Calendar.Component, Int) = {
            switch viewMode {
            case .month: return (.month, 1)
            case .week:  return (.weekOfYear, 1)
            case .day:   return (.day, 1)
            }
        }()
        if let next = cal.date(byAdding: delta, value: value, to: currentMonth) {
            monthTransitionDirection = 1
            currentMonth = next
            loadEventsForCurrentMonth()
        }
    }

    func goToToday() {
        let today = Date()
        monthTransitionDirection = today > currentMonth ? 1 : (today < currentMonth ? -1 : 0)
        currentMonth = today
        selectedDate = today
        loadEventsForCurrentMonth()
    }

    func setViewMode(_ mode: MacCalendarViewMode) {
        guard viewMode != mode else { return }
        viewMode = mode
        loadEventsForCurrentMonth()
    }

    // MARK: - Visible range helpers

    static func startOfWeek(for date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)   // 1 = Sun
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: -(weekday - 1), to: startOfDay) ?? startOfDay
    }

    func currentVisibleRange() -> (Date, Date) {
        visibleRange(for: viewMode, anchor: currentMonth)
    }

    private func visibleRange(for mode: MacCalendarViewMode, anchor: Date) -> (Date, Date) {
        let cal = Calendar.current
        switch mode {
        case .month:
            return visibleRangeMonth(for: anchor)
        case .week:
            let start = Self.startOfWeek(for: anchor)
            let end   = cal.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .day:
            let start = cal.startOfDay(for: anchor)
            let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
            return (start, end)
        }
    }

    /// 6주 = 42일 그리드. end 는 exclusive.
    private func visibleRangeMonth(for month: Date) -> (Date, Date) {
        let cal = Calendar.current
        let startOfMonth = cal.dateInterval(of: .month, for: month)?.start ?? month
        let weekday = cal.component(.weekday, from: startOfMonth)
        let startOfGrid = cal.date(byAdding: .day, value: -(weekday - 1), to: startOfMonth) ?? startOfMonth
        let endOfGrid = cal.date(byAdding: .day, value: 42, to: startOfGrid) ?? startOfMonth
        return (startOfGrid, endOfGrid)
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Range key

    private func rangeKey(for mode: MacCalendarViewMode, anchor: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        switch mode {
        case .month:
            f.dateFormat = "yyyy-MM"
            return "month_" + f.string(from: anchor)
        case .week:
            f.dateFormat = "yyyy-MM-dd"
            return "week_" + f.string(from: Self.startOfWeek(for: anchor))
        case .day:
            f.dateFormat = "yyyy-MM-dd"
            return "day_" + f.string(from: cal.startOfDay(for: anchor))
        }
    }

    // MARK: - Load (캐시 우선)

    func loadEventsForCurrentMonth(force: Bool = false) {
        let key = rangeKey(for: viewMode, anchor: currentMonth)

        if !force, loadedRangeKeys.contains(key) {
            // 이미 캐시에 있고 eventsByDate 에 union 으로 머지되어 있음 → 즉시 반환.
            isLoading = false
            prefetchAdjacent()
            return
        }

        fetchRange(viewMode: viewMode, anchor: currentMonth, isPrefetch: false) { [weak self] in
            self?.prefetchAdjacent()
        }
    }

    /// 주어진 view mode + anchor 의 이벤트를 fetch → 캐시 저장 → eventsByDate 에 union merge.
    /// CompositeCalendarSerivce 가 Apple/Dozy(/Google) 머지된 [CalendarEvent] 를 주고,
    /// 별도로 [DozyEvent] 도 받아 dozyEventsByID 에 채워서 일정 편집(우선순위/고정 등) 가능하게.
    private func fetchRange(
        viewMode: MacCalendarViewMode,
        anchor: Date,
        isPrefetch: Bool,
        onComplete: (() -> Void)? = nil
    ) {
        let key = rangeKey(for: viewMode, anchor: anchor)
        guard !inflightRangeKeys.contains(key) else { return }
        inflightRangeKeys.insert(key)

        let (start, end) = visibleRange(for: viewMode, anchor: anchor)

        if !isPrefetch {
            isLoading = true
            errorMessage = nil
        }

        Publishers.Zip(
            fetchCalendarEventsForPeriodUseCase.execute(from: start, to: end),
            fetchDozyEventsForPeriodUseCase.execute(from: start, to: end)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                self.inflightRangeKeys.remove(key)
                if case .failure(let error) = completion {
                    if !isPrefetch {
                        self.isLoading = false
                        self.errorMessage = error.errorDescription
                    }
                }
            },
            receiveValue: { [weak self] allEvents, dozyEvents in
                guard let self else { return }

                // 편집 가능한 DozyEvent 인덱스 — priority / isPinned / category 변경 시 사용.
                var byID: [String: DozyEvent] = [:]
                for d in dozyEvents { byID[d.id] = d }

                // Dozy 이벤트는 반복 / 멀티데이 해석을 위해 buildEventsByDate 로 처리.
                // Apple/Google 등 외부 소스 이벤트는 시작~종료일 범위로 bucket 처리.
                let dozyByDate = Self.buildEventsByDate(
                    dozyEvents: dozyEvents,
                    from: start,
                    to: end
                )
                let externalByDate = Self.bucketByDate(
                    events: allEvents.filter { $0.source != .dozy },
                    from: start,
                    to: end
                )

                var byDate = dozyByDate
                for (day, list) in externalByDate {
                    byDate[day, default: []].append(contentsOf: list)
                }
                for k in byDate.keys {
                    byDate[k]?.sort { a, b in
                        if a.isPinned != b.isPinned { return a.isPinned }
                        return a.startDate < b.startDate
                    }
                }

                self.cachedEventsByDate[key] = byDate
                self.cachedDozyEventsByID[key] = byID
                self.loadedRangeKeys.insert(key)

                // 항상 published 에 union merge — 현재 범위든 prefetch 든.
                // 같은 key 데이터는 새 값으로 교체되지만, 다른 key 의 데이터는 보존됨.
                self.eventsByDate.merge(byDate)   { _, new in new }
                self.dozyEventsByID.merge(byID)   { _, new in new }

                self.loadCompletions(for: start, to: end, key: key, isPrefetch: isPrefetch)
                onComplete?()
            }
        )
        .store(in: &cancellables)
    }

    private func loadCompletions(
        for start: Date,
        to end: Date,
        key: String,
        isPrefetch: Bool
    ) {
        fetchEventCompletionsForPeriodUseCase.execute(from: start, to: end)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completions in
                    guard let self else { return }
                    // composite key (eventID_dayTimestamp) — 다일/반복 이벤트 occurrence 별 독립 완료.
                    var map: [String: Bool] = [:]
                    for c in completions where c.isCompleted {
                        let k = EventCompletionRepository.completionKey(eventID: c.eventID, date: c.eventDate)
                        map[k] = true
                    }
                    // 같은 range 의 이전 cached 키들을 먼저 제거 — 토글 OFF (DB 에서 isCompleted=false
                    // 가 되어 map 에 포함 안 됨) 도 즉시 visual 반영. 다른 range 의 키는 보존.
                    if let oldMap = self.cachedCompletions[key] {
                        for oldKey in oldMap.keys {
                            self.completionsByID.removeValue(forKey: oldKey)
                        }
                    }
                    self.cachedCompletions[key] = map
                    for (k, v) in map {
                        self.completionsByID[k] = v
                    }

                    if !isPrefetch {
                        let currentKey = self.rangeKey(for: self.viewMode, anchor: self.currentMonth)
                        if key == currentKey { self.isLoading = false }
                    }
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Completion (toggle / read)

    /// occurrence 별 키 — Apple/Google 다일 이벤트나 반복 Dozy 이벤트도 정확히 구분.
    private func completionKey(for event: CalendarEvent, on date: Date) -> String {
        EventCompletionRepository.completionKey(eventID: event.id, date: date)
    }

    /// 화면에서 체크 표시 여부 판단. iOS 와 동일한 source 분기:
    /// - Dozy 비반복 → DozyEvent.isCompleted
    /// - Dozy 반복 → EventCompletion (occurrence 키)
    /// - Apple/Google → EventCompletion (선택 날짜 키)
    func isCompleted(for event: CalendarEvent, on date: Date) -> Bool {
        if event.source == .dozy {
            let dozy = dozyEventsByID[event.id]
            if let dozy, dozy.recurrenceRule != "none" {
                return completionsByID[completionKey(for: event, on: event.startDate)] ?? false
            }
            return dozy?.isCompleted ?? false
        }
        return completionsByID[completionKey(for: event, on: date)] ?? false
    }

    /// 일정 완료 토글. iOS 패턴 그대로 — Dozy 비반복은 DozyEvent.isCompleted 직접 토글,
    /// Dozy 반복 / Apple / Google 은 EventCompletion 테이블에 (eventID, eventDate) 저장.
    func toggleCompletion(for event: CalendarEvent, on date: Date) {
        if event.source == .dozy {
            guard let dozy = dozyEventsByID[event.id] else { return }
            if dozy.recurrenceRule == "none" {
                // UseCase 내부에서 toggle 하므로 호출부에서 또 뒤집으면 no-op. .execute 호출 직후
                // dozy 인스턴스는 동기로 새 값 반영됨.
                toggleDozyEventCompletionUseCase.execute(dozy)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                        self?.broadcastCompletionChange()
                    })
                    .store(in: &cancellables)
                dozyEventsByID[event.id] = dozy   // @Published 트리거 (isCompleted 새 값 반영용)
                return
            }
            // 반복 일정 — EventCompletion 으로 occurrence 별 토글
            let eventDate = event.startDate
            toggleCalendarEventCompletionUseCase.execute(eventID: event.id, eventDate: eventDate)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newValue in
                    guard let self else { return }
                    let key = EventCompletionRepository.completionKey(eventID: event.id, date: eventDate)
                    self.completionsByID[key] = newValue
                    self.broadcastCompletionChange()
                })
                .store(in: &cancellables)
            return
        }

        // Apple/Google — 선택 날짜 기준으로 occurrence 별 독립 완료
        toggleCalendarEventCompletionUseCase.execute(eventID: event.id, eventDate: date)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newValue in
                guard let self else { return }
                let key = EventCompletionRepository.completionKey(eventID: event.id, date: date)
                self.completionsByID[key] = newValue
                self.broadcastCompletionChange()
            })
            .store(in: &cancellables)
    }

    private func broadcastCompletionChange() {
        NotificationCenter.default.post(name: .dozyEventChanged, object: self)
    }

    /// 일정 자체가 생성·삭제·수정된 경우 — Today / MenuBar 가 리스트를 통째로 다시 로드.
    private func broadcastEventListChange() {
        NotificationCenter.default.post(name: .dozyEventListChanged, object: self)
    }

    // MARK: - Prefetch

    /// 현재 범위의 ±2 칸을 백그라운드로 미리 로드. 빠른 연속 스와이프에도 항상 캐시 한 칸 앞서있게.
    private func prefetchAdjacent() {
        let cal = Calendar.current
        let component: Calendar.Component = {
            switch viewMode {
            case .month: return .month
            case .week:  return .weekOfYear
            case .day:   return .day
            }
        }()
        for offset in [-2, -1, 1, 2] {
            guard let anchor = cal.date(byAdding: component, value: offset, to: currentMonth)
            else { continue }
            let key = rangeKey(for: viewMode, anchor: anchor)
            guard !loadedRangeKeys.contains(key), !inflightRangeKeys.contains(key) else { continue }
            fetchRange(viewMode: viewMode, anchor: anchor, isPrefetch: true)
        }
    }

    /// 사용자가 가입/생성한 공유 캘린더 목록 로드. 새 일정 / 일정 상세에서
    /// "공유 캘린더" Picker 에 노출.
    func loadMySharedCalendars() {
        sharedCalendarService.fetchMyCalendars()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] calendars in
                    self?.mySharedCalendars = calendars
                }
            )
            .store(in: &cancellables)
    }

    /// 앱 런치 직후 coordinator 가 호출. 월 기준 ±3 까지 병렬로 미리 요청해서
    /// 사용자가 캘린더 탭 누르기 전에 넓은 범위를 캐시에 적재.
    func prewarmWideWindow() {
        let cal = Calendar.current
        for offset in [-3, -2, 2, 3] {   // ±1 은 prefetchAdjacent 가 잡으므로 생략.
            guard let anchor = cal.date(byAdding: .month, value: offset, to: currentMonth)
            else { continue }
            let key = rangeKey(for: .month, anchor: anchor)
            guard !loadedRangeKeys.contains(key), !inflightRangeKeys.contains(key) else { continue }
            fetchRange(viewMode: .month, anchor: anchor, isPrefetch: true)
        }
    }

    // MARK: - Cache invalidation

    private func invalidateCache() {
        cachedEventsByDate.removeAll()
        cachedDozyEventsByID.removeAll()
        cachedCompletions.removeAll()
        loadedRangeKeys.removeAll()
        eventsByDate.removeAll()
        dozyEventsByID.removeAll()
        completionsByID.removeAll()
    }

    // MARK: - CRUD

    func saveDozyEvent(_ event: DozyEvent) {
        let isNew = dozyEventsByID[event.id] == nil
        let publisher = isNew
            ? createDozyEventUseCase.execute(event)
            : updateDozyEventUseCase.execute(event)
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.invalidateCache()
                    self?.loadEventsForCurrentMonth(force: true)
                    self?.broadcastEventListChange()
                }
            )
            .store(in: &cancellables)
    }

    func deleteDozyEvent(_ event: DozyEvent) {
        deleteDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.invalidateCache()
                    self?.loadEventsForCurrentMonth(force: true)
                    self?.broadcastEventListChange()
                }
            )
            .store(in: &cancellables)
    }

    /// 반복 일정의 특정 인스턴스만 제외
    func deleteThisOccurrence(_ event: DozyEvent, date: Date) {
        let occStart = event.occurrenceStart(for: date) ?? Calendar.current.startOfDay(for: date)
        event.excludedDates.append(occStart)
        event.updatedAt = Date()
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.invalidateCache()
                self?.loadEventsForCurrentMonth(force: true)
                self?.broadcastEventListChange()
            })
            .store(in: &cancellables)
    }

    /// 반복 일정의 특정 날짜 이후 모두 삭제
    func deleteFutureOccurrences(_ event: DozyEvent, from date: Date) {
        let cal = Calendar.current
        event.recurrenceEndDate = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))
        event.updatedAt = Date()
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.invalidateCache()
                self?.loadEventsForCurrentMonth(force: true)
                self?.broadcastEventListChange()
            })
            .store(in: &cancellables)
    }

    /// 메모 저장 (DozyEvent.memos 를 외부에서 이미 변경하고 이 함수로 sync)
    func saveMemos(for event: DozyEvent) {
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    /// 표시 설정(고정 / 우선순위 / 카테고리) 업데이트.
    func updateDisplaySettings(for event: CalendarEvent, priority: Int, isPinned: Bool, category: String?) {
        guard let dozy = dozyEventsByID[event.id] else { return }
        dozy.priority = priority
        dozy.isPinned = isPinned
        if let category {
            dozy.category = category
            if let ctx = dozy.modelContext,
               let cat = try? ctx.fetch(FetchDescriptor<UserCategory>()).first(where: { $0.name == category }) {
                dozy.colorHex = cat.colorHex
            }
        }
        dozy.updatedAt = Date()
        updateDozyEventUseCase.execute(dozy)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.invalidateCache()
                self?.loadEventsForCurrentMonth(force: true)
            })
            .store(in: &cancellables)
    }

    // MARK: - buildEventsByDate (최적화)

    /// 비반복 멀티데이: 시작일~종료일 범위 직접 fill (O(N × avgDuration))
    /// 반복: 날짜별 occursOn 체크
    /// startOfDay 는 이벤트별 1회만 계산, 정렬은 날짜별 1회.
    private static func buildEventsByDate(
        dozyEvents: [DozyEvent],
        from start: Date,
        to end: Date
    ) -> [Date: [CalendarEvent]] {
        let cal = Calendar.current
        let rangeStart = cal.startOfDay(for: start)
        let rangeEnd   = cal.startOfDay(for: end)   // exclusive
        let lastIncluded = cal.date(byAdding: .day, value: -1, to: rangeEnd) ?? rangeEnd

        var result: [Date: [CalendarEvent]] = [:]

        for event in dozyEvents {
            if event.recurrenceRule == "none" {
                let s = cal.startOfDay(for: event.startDate)
                let e = cal.startOfDay(for: event.endDate)
                let effStart = max(s, rangeStart)
                let effEnd   = min(e, lastIncluded)
                guard effStart <= effEnd else { continue }

                let calEvent = event.toCalendarEvent()
                var cursor = effStart
                while cursor <= effEnd {
                    result[cursor, default: []].append(calEvent)
                    guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                }
            } else {
                var cursor = rangeStart
                while cursor < rangeEnd {
                    if event.occursOn(cursor) {
                        result[cursor, default: []].append(event.toCalendarEvent(for: cursor))
                    }
                    guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                }
            }
        }

        for key in result.keys {
            result[key]?.sort { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.startDate < b.startDate
            }
        }

        return result
    }

    /// Apple/Google 등 외부 소스 이벤트를 날짜별 버킷으로. 멀티데이는 시작~종료일 범위 fill.
    /// 정렬은 호출 측(fetchRange) 에서 dozy 와 머지 후 한 번에 수행한다.
    private static func bucketByDate(
        events: [CalendarEvent],
        from start: Date,
        to end: Date
    ) -> [Date: [CalendarEvent]] {
        let cal = Calendar.current
        let rangeStart = cal.startOfDay(for: start)
        let rangeEnd   = cal.startOfDay(for: end)
        let lastIncluded = cal.date(byAdding: .day, value: -1, to: rangeEnd) ?? rangeEnd

        var result: [Date: [CalendarEvent]] = [:]
        for event in events {
            let s = cal.startOfDay(for: event.startDate)
            let e = cal.startOfDay(for: event.endDate)
            let effStart = max(s, rangeStart)
            let effEnd   = min(e, lastIncluded)
            guard effStart <= effEnd else { continue }
            var cursor = effStart
            while cursor <= effEnd {
                result[cursor, default: []].append(event)
                guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        return result
    }
}
