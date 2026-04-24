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

    @Published var currentMonth: Date = Date()
    @Published var selectedDate: Date = Date()
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
        f.dateFormat = "yyyy년 M월"
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

    func goToPreviousMonth() {
        let cal = Calendar.current
        if let prev = cal.date(byAdding: .month, value: -1, to: currentMonth) {
            monthTransitionDirection = -1
            currentMonth = prev
            loadEventsForCurrentMonth()
        }
    }

    func goToNextMonth() {
        let cal = Calendar.current
        if let next = cal.date(byAdding: .month, value: 1, to: currentMonth) {
            monthTransitionDirection = 1
            currentMonth = next
            loadEventsForCurrentMonth()
        }
    }

    func goToToday() {
        let today = Date()
        let cal = Calendar.current
        let currentStart = cal.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let todayStart   = cal.dateInterval(of: .month, for: today)?.start ?? today
        monthTransitionDirection = todayStart > currentStart ? 1 : (todayStart < currentStart ? -1 : 0)
        currentMonth = today
        selectedDate = today
        loadEventsForCurrentMonth()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Data

    func loadEventsForCurrentMonth() {
        let (start, end) = visibleRange(for: currentMonth)
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

    // MARK: - Helpers

    /// 달력 그리드에서 보이는 날짜 범위 (6주 = 42일).
    /// 해당 월 1일이 속한 주의 일요일부터 42일간.
    private func visibleRange(for month: Date) -> (Date, Date) {
        let cal = Calendar.current
        let startOfMonth = cal.dateInterval(of: .month, for: month)?.start ?? month
        let weekday = cal.component(.weekday, from: startOfMonth) // 1 = Sunday
        let startOfGrid = cal.date(byAdding: .day, value: -(weekday - 1), to: startOfMonth) ?? startOfMonth
        let endOfGrid = cal.date(byAdding: .day, value: 41, to: startOfGrid) ?? startOfMonth
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
        while cursor <= limit {
            var list: [CalendarEvent] = []
            for event in dozyEvents {
                if event.recurrenceRule == "none" {
                    let s = cal.startOfDay(for: event.startDate)
                    let e = cal.startOfDay(for: event.endDate)
                    if cursor >= s && cursor <= e {
                        list.append(event.toCalendarEvent(for: cursor))
                    }
                } else if event.occursOn(cursor) {
                    list.append(event.toCalendarEvent(for: cursor))
                }
            }
            if !list.isEmpty {
                result[cursor] = list.sorted { $0.startDate < $1.startDate }
            }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? limit
        }
        return result
    }
}
