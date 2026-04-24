//
//  MacCalendarViewModel.swift
//  Dozy AI (macOS)
//
//  M4.5 — 월별 캘린더 뷰 전용 ViewModel. 현재 월(및 앞뒤 여유)에 해당하는
//  DozyEvent 를 Supabase 에서 받아와 날짜별로 그룹핑, 선택된 날짜의 일정 리스트를
//  제공한다. iOS CalendarViewModel 의 기능 중 핵심만 추려 단순화.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class MacCalendarViewModel: ObservableObject {

    // MARK: - Published

    @Published var currentMonth: Date = Date()   // 앵커 날짜 (뷰 모드에 따라 의미 달라짐)
    @Published var selectedDate: Date = Date()
    @Published var viewMode: MacCalendarViewMode = .month
    /// 월 이동 방향 — 1: 다음(오른쪽), -1: 이전(왼쪽), 0: 초기/무방향. 슬라이드 애니메이션용.
    @Published var monthTransitionDirection: Int = 0
    @Published var eventsByDate: [Date: [CalendarEvent]] = [:]
    @Published var dozyEventsByID: [String: DozyEvent] = [:]
    @Published var completionsByID: [String: Bool] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Deps

    private let fetchDozyEventsForPeriodUseCase: FetchDozyEventsForPeriodUseCase
    private let fetchEventCompletionsForPeriodUseCase: FetchEventCompletionsForPeriodUseCase
    private let createDozyEventUseCase: CreateDozyEventUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let deleteDozyEventUseCase: DeleteDozyEventUseCase
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
            // "2026년 4월 3주차" 또는 "Apr 20 - Apr 26, 2026" 스타일. 심플하게 시작일 기반.
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
        self.fetchEventCompletionsForPeriodUseCase = container.fetchEventCompletionsForPeriodUseCase
        self.createDozyEventUseCase = container.createDozyEventUseCase
        self.updateDozyEventUseCase = container.updateDozyEventUseCase
        self.deleteDozyEventUseCase = container.deleteDozyEventUseCase

        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadEventsForCurrentMonth() }
            .store(in: &cancellables)
    }

    // MARK: - Month Navigation

    // MARK: - Navigation (view mode 에 따라 동작 변경)

    func goToPreviousMonth() {
        let cal = Calendar.current
        let delta: Calendar.Component
        let value: Int
        switch viewMode {
        case .month: delta = .month; value = -1
        case .week:  delta = .weekOfYear; value = -1
        case .day:   delta = .day; value = -1
        }
        if let prev = cal.date(byAdding: delta, value: value, to: currentMonth) {
            monthTransitionDirection = -1
            currentMonth = prev
            loadEventsForCurrentMonth()
        }
    }

    func goToNextMonth() {
        let cal = Calendar.current
        let delta: Calendar.Component
        let value: Int
        switch viewMode {
        case .month: delta = .month; value = 1
        case .week:  delta = .weekOfYear; value = 1
        case .day:   delta = .day; value = 1
        }
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

    /// 현재 뷰 모드에 따라 보여지는 날짜 범위.
    /// end 는 마지막 표시일의 다음날 시작(= exclusive upper bound) 을 사용해야
    /// DozyEventRepository 의 predicate `startDate < end` 가 마지막날 이벤트까지 포함한다.
    func currentVisibleRange() -> (Date, Date) {
        let cal = Calendar.current
        switch viewMode {
        case .month:
            return visibleRangeMonth(for: currentMonth)
        case .week:
            let start = Self.startOfWeek(for: currentMonth)
            let end   = cal.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .day:
            let start = cal.startOfDay(for: currentMonth)
            let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
            return (start, end)
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Data

    func loadEventsForCurrentMonth() {
        let (start, end) = currentVisibleRange()
        isLoading = true
        errorMessage = nil

        fetchDozyEventsForPeriodUseCase.execute(from: start, to: end)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] dozyEvents in
                    guard let self else { return }
                    var byID: [String: DozyEvent] = [:]
                    for d in dozyEvents { byID[d.id] = d }
                    self.dozyEventsByID = byID
                    self.eventsByDate = Self.buildEventsByDate(
                        dozyEvents: dozyEvents,
                        from: start,
                        to: end
                    )
                    self.loadCompletions(for: start, to: end)
                }
            )
            .store(in: &cancellables)
    }

    private func loadCompletions(for start: Date, to end: Date) {
        fetchEventCompletionsForPeriodUseCase.execute(from: start, to: end)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completions in
                    var map: [String: Bool] = [:]
                    for c in completions where c.isCompleted {
                        map[c.eventID] = true
                    }
                    self?.completionsByID = map
                }
            )
            .store(in: &cancellables)
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
                receiveValue: { [weak self] in self?.loadEventsForCurrentMonth() }
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
                receiveValue: { [weak self] in self?.loadEventsForCurrentMonth() }
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
                self?.loadEventsForCurrentMonth()
            })
            .store(in: &cancellables)
    }

    /// 반복 일정의 특정 날짜 이후 모두 삭제 (recurrenceEndDate 를 전날로 단축)
    func deleteFutureOccurrences(_ event: DozyEvent, from date: Date) {
        let cal = Calendar.current
        event.recurrenceEndDate = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))
        event.updatedAt = Date()
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadEventsForCurrentMonth()
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

    /// 표시 설정 (고정 / 우선순위 / 카테고리) 업데이트. 카테고리 변경 시 색상도 동기화.
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
                self?.loadEventsForCurrentMonth()
            })
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    /// 달력 그리드에서 보이는 날짜 범위 (6주 = 42일).
    /// 해당 월 1일이 속한 주의 일요일부터 42일간.
    /// end 는 Day 42 시작(= exclusive) 으로, predicate `startDate < end` 가 Day 41 이벤트까지 포함.
    private func visibleRangeMonth(for month: Date) -> (Date, Date) {
        let cal = Calendar.current
        let startOfMonth = cal.dateInterval(of: .month, for: month)?.start ?? month
        let weekday = cal.component(.weekday, from: startOfMonth) // 1 = Sunday
        let startOfGrid = cal.date(byAdding: .day, value: -(weekday - 1), to: startOfMonth) ?? startOfMonth
        let endOfGrid = cal.date(byAdding: .day, value: 42, to: startOfGrid) ?? startOfMonth
        return (startOfGrid, endOfGrid)
    }

    /// 주어진 기간 내 각 날짜에 해당하는 DozyEvent 를 CalendarEvent 로 변환해 날짜별 맵 생성.
    /// 반복(recurrenceRule != "none") 은 `occursOn(_:)` 으로 판정,
    /// 비반복은 start~end 일자 범위로 판정 (다중일 이벤트 처리).
    private static func buildEventsByDate(
        dozyEvents: [DozyEvent],
        from start: Date,
        to end: Date
    ) -> [Date: [CalendarEvent]] {
        let cal = Calendar.current
        var result: [Date: [CalendarEvent]] = [:]
        var cursor = cal.startOfDay(for: start)
        let limit = cal.startOfDay(for: end)
        while cursor < limit {   // end 는 exclusive (다음날 시작)
            var list: [CalendarEvent] = []
            for event in dozyEvents {
                if event.recurrenceRule == "none" {
                    let s = cal.startOfDay(for: event.startDate)
                    let e = cal.startOfDay(for: event.endDate)
                    if cursor >= s && cursor <= e {
                        // 비반복 멀티데이 이벤트는 원본 날짜 유지 (diff shift 하면 바 span 밀림)
                        list.append(event.toCalendarEvent())
                    }
                } else if event.occursOn(cursor) {
                    list.append(event.toCalendarEvent(for: cursor))
                }
            }
            if !list.isEmpty {
                result[cursor] = list.sorted { a, b in
                    if a.isPinned != b.isPinned { return a.isPinned }
                    return a.startDate < b.startDate
                }
            }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? limit
        }
        return result
    }
}
