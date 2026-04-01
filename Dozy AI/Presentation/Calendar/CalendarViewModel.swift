//
//  CalendarViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

enum CalendarViewMode: CaseIterable {
    case month, week, day
    var title: String {
        switch self {
        case .month: return "월"
        case .week: return "주"
        case .day: return "일"
        }
    }
}

// MARK: - EventBarInfo (ViewModel 전용 - SwiftUI 없음)
struct EventBarInfo: Identifiable {
    let id: String
    let colorHex: String
}

final class CalendarViewModel: ObservableObject {

    // MARK: - Published
    @Published var currentMonth: Date = Date()
    @Published var selectedDate: Date = Date()
    @Published var eventsForSelectedDate: [CalendarEvent] = []
    @Published var dozyEventsForSelectedDate: [DozyEvent] = []
    @Published var dozyEventsByID: [String: DozyEvent] = [:]
    @Published var showDeleteAlert = false
    @Published var pendingDeleteEvent: DozyEvent? = nil
    @Published var eventBarsPerDate: [Date: [EventBarInfo]] = [:]
    @Published var viewMode: CalendarViewMode = .month
    @Published var isLoading = false
    @Published var showEventDetail = false
    @Published var detailEvent: CalendarEvent? = nil
    @Published var showEventEdit = false
    @Published var eventToEdit: DozyEvent? = nil
    
    // MARK: - Dependencies
    private let fetchEventsUseCase: FetchCalendarEventUseCase
    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let createEventUseCase: CreateDozyEventUseCase
    private let updateEventUseCase: UpdateDozyEventUseCase
    private let deleteEventUseCase: DeleteDozyEventUseCase
    private let scheduleNotificationUseCase: ScheduleNotificationUseCase
    private let cancelNotificationUseCase: CancelNotificationUseCase
    private let toggleCompletionUseCase: ToggleDozyEventCompletionUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(
        fetchEventsUseCase: FetchCalendarEventUseCase,
        fetchDozyEventsUseCase: FetchDozyEventsUseCase,
        createEventUseCase: CreateDozyEventUseCase,
        updateEventUseCase: UpdateDozyEventUseCase,
        deleteEventUseCase: DeleteDozyEventUseCase,
        scheduleNotificationUseCase: ScheduleNotificationUseCase,
        cancelNotificationUseCase: CancelNotificationUseCase,
        toggleCompletionUseCase: ToggleDozyEventCompletionUseCase
    ) {
        self.fetchEventsUseCase = fetchEventsUseCase
        self.fetchDozyEventsUseCase = fetchDozyEventsUseCase
        self.createEventUseCase = createEventUseCase
        self.updateEventUseCase = updateEventUseCase
        self.deleteEventUseCase = deleteEventUseCase
        self.scheduleNotificationUseCase = scheduleNotificationUseCase
        self.cancelNotificationUseCase = cancelNotificationUseCase
        self.toggleCompletionUseCase = toggleCompletionUseCase
    }
    
    convenience init(container: DependencyContainer) {
        self.init(
            fetchEventsUseCase: container.fetchCalendarEventUseCase,
            fetchDozyEventsUseCase: container.fetchDozyEventsUseCase,
            createEventUseCase: container.createDozyEventUseCase,
            updateEventUseCase: container.updateDozyEventUseCase,
            deleteEventUseCase: container.deleteDozyEventUseCase,
            scheduleNotificationUseCase: container.scheduleNotificationUseCase,
            cancelNotificationUseCase: container.cancelNotificationUseCase,
            toggleCompletionUseCase: container.toggleDozyEventCompletionUseCase
        )
    }
    
    // MARK: - Computed
    
    var currentMonthString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy년 M월"
        fmt.locale = Locale(identifier: "ko_KR")
        return fmt.string(from: currentMonth)
    }
    
    var currentWeekDates: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate) - 1
        let startOfWeek = cal.date(byAdding: .day, value: -weekday, to: selectedDate)!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var currentPeriodString: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        switch viewMode {
        case .month:
            fmt.dateFormat = "yyyy년 M월"
            return fmt.string(from: currentMonth)
        case .week:
            fmt.dateFormat = "M월 d일"
            let dates = currentWeekDates
            let start = fmt.string(from: dates.first ?? selectedDate)
            let end = fmt.string(from: dates.last ?? selectedDate)
            return "\(start) - \(end)"
        case .day:
            fmt.dateFormat = "yyyy년 M월 d일 (E)"
            return fmt.string(from: selectedDate)
        }
    }
    
    func dozyEvent(for calendarEvent: CalendarEvent) -> DozyEvent? {
        guard calendarEvent.source == .dozy else { return nil }
        return dozyEventsByID[calendarEvent.id]
    }

    func showDetail(for event: CalendarEvent) {
        detailEvent = event
        showEventDetail = true
    }
    
    func toggleCompletion(for event: DozyEvent) {
        toggleCompletionUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.dozyEventsByID[event.id] = event
                self.fetchEventsForDate(self.selectedDate)
            })
            .store(in: &cancellables)
    }
    
    // 월간 그리드용 날짜 배열 (앞 padding은 nil)
    var daysInMonth: [Date?] {
        let calendar = Calendar.current
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let weekday = calendar.component(.weekday, from: first) - 1
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            var comps = calendar.dateComponents([.year, .month], from: currentMonth)
            comps.day = day
            days.append(calendar.date(from: comps))
        }
        return days
    }
    
    func hasEvents(on date: Date) -> Bool {
        let key = Calendar.current.startOfDay(for: date)
        return !(eventBarsPerDate[key]?.isEmpty ?? true)
    }
    
    func eventBars(for date: Date) -> [EventBarInfo] {
        let key = Calendar.current.startOfDay(for: date)
        return eventBarsPerDate[key] ?? []
    }
    
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    // MARK: - Navigation
    
    func previousPeriod() {
        let cal = Calendar.current
        switch viewMode {
        case .month:
            currentMonth = cal.date(byAdding: .month, value: -1, to: currentMonth)!
            fetchEventsForMonth()
        case .week:
            selectedDate = cal.date(byAdding: .day, value: -7, to: selectedDate)!
            fetchEventsForDate(selectedDate)
        case .day:
            selectedDate = cal.date(byAdding: .day, value: -1, to: selectedDate)!
            fetchEventsForDate(selectedDate)
        }
    }
    
    func nextPeriod() {
        let cal = Calendar.current
        switch viewMode {
        case .month:
            currentMonth = cal.date(byAdding: .month, value: 1, to: currentMonth)!
            fetchEventsForMonth()
        case .week:
            selectedDate = cal.date(byAdding: .day, value: 7, to: selectedDate)!
            fetchEventsForDate(selectedDate)
        case .day:
            selectedDate = cal.date(byAdding: .day, value: 1, to: selectedDate)!
            fetchEventsForDate(selectedDate)
        }
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
        fetchEventsForDate(date)
    }
    
    // MARK: - Fetch
    
    func loadInitialData() {
        fetchEventsForDate(selectedDate)
        fetchEventsForMonth()
    }
    
    private func fetchEventsForDate(_ date: Date) {
        isLoading = true
        Publishers.Zip(
            fetchEventsUseCase.execute(for: date),
            fetchDozyEventsUseCase.execute(for: date)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] _ in self?.isLoading = false },
            receiveValue: { [weak self] events, dozyEvents in
                self?.eventsForSelectedDate = events
                self?.dozyEventsForSelectedDate = dozyEvents
                self?.dozyEventsByID = Dictionary(uniqueKeysWithValues: dozyEvents.map { ($0.id, $0) })
                self?.isLoading = false
            }
        )
        .store(in: &cancellables)
    }
    
    private func fetchEventsForMonth() {
        guard let interval = Calendar.current.dateInterval(of: .month, for: currentMonth) else { return }
        
        var date = interval.start
        var publishers: [AnyPublisher<(Date, [CalendarEvent]), DozyError>] = []
        
        while date < interval.end {
            let d = date
            publishers.append(
                fetchEventsUseCase.execute(for: d).map { (d, $0) }.eraseToAnyPublisher()
            )
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] results in
                    var barsDict: [Date: [EventBarInfo]] = [:]
                    for (date, events) in results where !events.isEmpty {
                        let key = Calendar.current.startOfDay(for: date)
                        
                        barsDict[key] = events.prefix(3).map {
                            EventBarInfo(id: $0.id, colorHex: $0.calendarColorHex)
                        }
                    }
                    self?.eventBarsPerDate = barsDict
                }
            ).store(in: &cancellables)
    }
    
    // MARK: - CRUD
    
    func startCreatingEvent() {
        eventToEdit = nil
        showEventEdit = true
    }
    
    func startEditingEvent(_ event: DozyEvent) {
        eventToEdit = event
        showEventEdit = true
    }
    
    func saveEvent(_ event: DozyEvent) {
        let useCase = eventToEdit != nil ? updateEventUseCase.execute(event) : createEventUseCase.execute(event)
        useCase
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.fetchEventsForDate(self.selectedDate)
                self.fetchEventsForMonth()
                self.cancelNotificationUseCase.execute(identifier: event.id)
                if event.notificationMinutesBefore >= 0 {
                    self.scheduleNotificationUseCase.execute(for: event)
                }
            }).store(in: &cancellables)
    }
    
    func requestDelete(_ event: DozyEvent) {
        pendingDeleteEvent = event
        showDeleteAlert = true
    }

    func deleteEvent(_ event: DozyEvent) {
        cancelNotificationUseCase.execute(identifier: event.id)
        deleteEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.fetchEventsForDate(self.selectedDate)
                self.fetchEventsForMonth()
            }).store(in: &cancellables)
    }
}
