//
//  CalendarViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine
import SwiftUI

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

struct CalendarEventLayout: Identifiable {
    let id: String
    let title: String
    let colorHex: String
    let source: CalendarSource
    let startCol: Int
    let endCol: Int
    let row: Int
    let isActualStart: Bool
    let isActualEnd: Bool
    let isPinned: Bool
    let priority: Int
}

enum BarPosition {
    case single, start, middle, end
}

struct EventBarInfo: Identifiable {
    let id: String
    let colorHex: String
    let position: BarPosition
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
    @Published var pendingDeleteCalendarEvent: CalendarEvent? = nil
    @Published var eventBarsPerDate: [Date: [EventBarInfo]] = [:]
    @Published var viewMode: CalendarViewMode = .month
    @Published var isLoading = false
    @Published var showEventDetail = false
    @Published var detailEvent: CalendarEvent? = nil
    @Published var showEventEdit = false
    @Published var eventToEdit: DozyEvent? = nil
    @Published var completionsByID: [String: Bool] = [:]
    @Published var showCalendarEventEdit = false
    @Published var calendarEventToEdit: CalendarEvent? = nil
    @Published var weekLayouts: [Date: [CalendarEventLayout]] = [:]
    @Published var deleteErrorMessage: String? = nil
    @Published var showDeleteSuccess = false
    @Published var showSuccessAnimation = false
    @Published var displaySettingsByID: [String: EventDisplaySettings] = [:]
    private var allEventsInMonth: [String: CalendarEvent] = [:]
    
    // MARK: - Dependencies
    private let fetchEventsUseCase: FetchCalendarEventUseCase
    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let createEventUseCase: CreateDozyEventUseCase
    private let updateEventUseCase: UpdateDozyEventUseCase
    private let deleteEventUseCase: DeleteDozyEventUseCase
    private let scheduleNotificationUseCase: ScheduleNotificationUseCase
    private let cancelNotificationUseCase: CancelNotificationUseCase
    private let toggleCompletionUseCase: ToggleDozyEventCompletionUseCase
    private let updateCalendarEventUseCase: UpdateCalendarEventUseCase
    private let deleteCalendarEventUseCase: DeleteCalendarEventUseCase
    private let toggleCalendarEventCompletionUseCase: ToggleCalendarEventCompletionUseCase
    private let fetchEventCompletionsUseCase: FetchEventCompletionsUseCase
    private let fetchDozyEventsForPeriodUseCase: FetchDozyEventsForPeriodUseCase
    private weak var calendarService: CompositeCalendarSerivce?
    private var cancellables = Set<AnyCancellable>()
    private let displaySettingsRepo: EventDisplaySettingsRepository
    
    init(
        fetchEventsUseCase: FetchCalendarEventUseCase,
        fetchDozyEventsUseCase: FetchDozyEventsUseCase,
        createEventUseCase: CreateDozyEventUseCase,
        updateEventUseCase: UpdateDozyEventUseCase,
        deleteEventUseCase: DeleteDozyEventUseCase,
        scheduleNotificationUseCase: ScheduleNotificationUseCase,
        cancelNotificationUseCase: CancelNotificationUseCase,
        toggleCompletionUseCase: ToggleDozyEventCompletionUseCase,
        updateCalendarEventUseCase: UpdateCalendarEventUseCase,
        deleteCalendarEventUseCase: DeleteCalendarEventUseCase,
        toggleCalendarEventCompletionUseCase: ToggleCalendarEventCompletionUseCase,
        fetchEventCompletionsUseCase: FetchEventCompletionsUseCase,
        fetchDozyEventsForPeriodUseCase: FetchDozyEventsForPeriodUseCase,
        displaySettingsRepo: EventDisplaySettingsRepository
    ) {
        self.fetchEventsUseCase = fetchEventsUseCase
        self.fetchDozyEventsUseCase = fetchDozyEventsUseCase
        self.createEventUseCase = createEventUseCase
        self.updateEventUseCase = updateEventUseCase
        self.deleteEventUseCase = deleteEventUseCase
        self.scheduleNotificationUseCase = scheduleNotificationUseCase
        self.cancelNotificationUseCase = cancelNotificationUseCase
        self.toggleCompletionUseCase = toggleCompletionUseCase
        self.updateCalendarEventUseCase = updateCalendarEventUseCase
        self.deleteCalendarEventUseCase = deleteCalendarEventUseCase
        self.toggleCalendarEventCompletionUseCase = toggleCalendarEventCompletionUseCase
        self.fetchEventCompletionsUseCase = fetchEventCompletionsUseCase
        self.fetchDozyEventsForPeriodUseCase = fetchDozyEventsForPeriodUseCase
        self.displaySettingsRepo = displaySettingsRepo
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
            toggleCompletionUseCase: container.toggleDozyEventCompletionUseCase,
            updateCalendarEventUseCase: container.updateCalendarEventUseCase,
            deleteCalendarEventUseCase: container.deleteCalendarEventUseCase,
            toggleCalendarEventCompletionUseCase: container.toggleCalendarEventCompletionUseCase,
            fetchEventCompletionsUseCase: container.fetchEventCompletionsUseCase,
            fetchDozyEventsForPeriodUseCase: container.fetchDozyEventsForPeriodUseCase,
            displaySettingsRepo: container.eventDisplaySettingsRepository
        )
        self.calendarService = container.calendarService
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
    
    var weeksInMonth: [[Date?]] {
        var days = daysInMonth
        while days.count % 7 != 0 { days.append(nil) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0+7]) }
    }
    
    func weekStart(for weekIndex: Int) -> Date {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth))!
        let weekday = cal.component(.weekday, from: first) - 1
        let displayStart = cal.date(byAdding: .day, value: -weekday, to: first)!
        return cal.date(byAdding: .day, value: weekIndex * 7, to: displayStart)!
    }
    
    func dozyEvent(for calendarEvent: CalendarEvent) -> DozyEvent? {
        guard calendarEvent.source == .dozy else { return nil }
        return dozyEventsByID[calendarEvent.id]
    }

    func showDetail(for event: CalendarEvent) {
        detailEvent = event
        showEventDetail = true
    }

    func showDetailForEventID(_ id: String) {
        if let event = eventsForSelectedDate.first(where: { $0.id == id }) {
            showDetail(for: event)
        } else if let event = allEventsInMonth[id] {
            showDetail(for: event)
        }
    }
    
    func toggleCompletion(for event: DozyEvent) {
        toggleCompletionUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.dozyEventsByID[event.id] = event
            })
            .store(in: &cancellables)
    }
    
    // 완료 상태 통합 조회
    func isCompleted(for event: CalendarEvent) -> Bool {
        if event.source == .dozy {
            return dozyEventsByID[event.id]?.isCompleted ?? false
        }
        return completionsByID[event.id] ?? false
    }
    
    // 완료 토글 (source 분기)
    func toggleCompletion(for event: CalendarEvent) {
        if event.source == .dozy {
            guard let dozyEvent = dozyEventsByID[event.id] else { return }
            toggleCompletion(for: dozyEvent)
        } else {
            toggleCalendarEventCompletionUseCase.execute(eventID: event.id, eventDate: event.startDate)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newValue in
                    self?.completionsByID[event.id] = newValue
                })
                .store(in: &cancellables)
        }
    }
    
    // Apple/Google 수정 시작
    func startEditingCalendarEvent(_ event: CalendarEvent) {
        calendarEventToEdit = event
        showCalendarEventEdit = true
    }
    
    // Apple/Google 수정 저장
    func saveCalendarEvent(_ event: CalendarEvent, edit: CalendarEventEditRequest) {
        updateCalendarEventUseCase.execute(event, with: edit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.fetchEventsForDate(self?.selectedDate ?? Date())
                self?.fetchEventsForMonth()
            })
            .store(in: &cancellables)
    }
    
    // Apple/Google 삭제 요청
    func requestDeleteCalendarEvent(_ event: CalendarEvent) {
        pendingDeleteCalendarEvent = event
        showDeleteAlert = true
    }
    
    // Apple/Google 삭제 실행
    func deleteCalendarEvent(_ event: CalendarEvent) {
        deleteCalendarEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.deleteErrorMessage = error.errorDescription ?? "삭제에 실패했습니다."
                    }
                },
                receiveValue: { [weak self] in
                    guard let self else { return }
                    self.showEventDetail = false
                    self.showDeleteSuccess = true
                    // 낙관적 업데이트: EventKit 캐시 반영 전에 즉시 목록/그리드에서 제거
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.eventsForSelectedDate.removeAll { $0.id == event.id }
                        for key in self.weekLayouts.keys {
                            self.weekLayouts[key]?.removeAll { $0.id == event.id }
                        }
                        for key in self.eventBarsPerDate.keys {
                            self.eventBarsPerDate[key]?.removeAll { $0.id == event.id }
                        }
                    }
                    // EventKit 동기화 후 재조회
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        self?.fetchEventsForDate(self?.selectedDate ?? Date())
                        self?.fetchEventsForMonth()
                    }
                }
            )
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
        // displaySettings를 먼저 로드한 뒤 fetch — buildLayouts에서 설정이 반영되도록
        displaySettingsRepo.fetchAll()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self else { return }
                self.displaySettingsByID = settings
                self.fetchEventsForDate(self.selectedDate)
                self.fetchEventsForMonth()
            }
            .store(in: &cancellables)
    }

    func refreshData() {
        calendarService?.invalidateGoogleCache()
        loadInitialData()
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
                guard let self else { return }

                // DozyEvent 업데이트
                let newEntries = Dictionary(uniqueKeysWithValues: dozyEvents.map { ($0.id, $0) })
                self.dozyEventsForSelectedDate = dozyEvents
                self.dozyEventsByID.merge(newEntries) { _, new in new }

                // Apple/Google completion 조회
                let nonDozyIDs = events.filter { $0.source != .dozy }.map { $0.id }
                if !nonDozyIDs.isEmpty {
                    self.fetchEventCompletionsUseCase.execute(for: nonDozyIDs)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { _ in }, receiveValue: { dict in
                            self.completionsByID.merge(dict) { _, new in new }
                        })
                        .store(in: &self.cancellables)
                }

                // Apple/Google 이벤트에 display settings 오버라이드 적용 후 정렬
                self.displaySettingsRepo.fetchAll(for: nonDozyIDs)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] settings in
                        guard let self else { return }
                        self.displaySettingsByID.merge(settings) { _, new in new }
                        let applied = events.map { $0.applying(self.displaySettingsByID[$0.id]) }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.eventsForSelectedDate = applied.sorted { a, b in
                                if a.isPinned != b.isPinned { return a.isPinned }
                                if a.priority != b.priority {
                                    let pa = a.priority == 0 ? Int.max : a.priority
                                    let pb = b.priority == 0 ? Int.max : b.priority
                                    return pa < pb
                                }
                                return a.startDate < b.startDate
                            }
                        }
                        self.isLoading = false
                    }
                    .store(in: &self.cancellables)
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Display Settings

    func updateDisplaySettings(for event: CalendarEvent, priority: Int, isPinned: Bool) {
        if event.source == .dozy {
            guard let dozy = dozyEventsByID[event.id] else { return }
            dozy.priority = priority
            dozy.isPinned = isPinned
            updateEventUseCase.execute(dozy)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                    self?.fetchEventsForDate(self?.selectedDate ?? Date())
                    self?.fetchEventsForMonth()
                })
                .store(in: &cancellables)
        } else {
            displaySettingsRepo.save(eventID: event.id, priority: priority, isPinned: isPinned)
            fetchEventsForDate(selectedDate)
            fetchEventsForMonth()
        }
    }
    
    private func fetchEventsForMonth() {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return }
        
        // 표시 범위 확장 (첫째 주/마지막 주 이전달, 다음달 날짜 포함)
        let firstWeekday = cal.component(.weekday, from: interval.start) - 1
        let displayStart = cal.date(byAdding: .day, value: -firstWeekday, to: interval.start)!
        
        let lastDay = cal.date(byAdding: .day, value: -1, to: interval.end)!
        let lastWeekday = cal.component(.weekday, from: lastDay) - 1
        let displayEnd = cal.date(byAdding: .day, value: 7 - lastWeekday, to: lastDay)!
        
        var date = displayStart
        var publishers: [AnyPublisher<(Date, [CalendarEvent]), DozyError>] = []
        while date < displayEnd {
            let d = date
            publishers.append(fetchEventsUseCase.execute(for: d).map { (d, $0) }.eraseToAnyPublisher())
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] results in
                guard let self else { return }
                self.buildLayouts(from: results)
            })
            .store(in: &cancellables)

        // 월 전체 DozyEvent를 dozyEventsByID에 미리 로드 (모든 날짜 탭 시 조회 가능하게)
        fetchDozyEventsForPeriodUseCase.execute(from: displayStart, to: displayEnd)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] dozyEvents in
                guard let self else { return }
                let newEntries = Dictionary(uniqueKeysWithValues: dozyEvents.map { ($0.id, $0) })
                self.dozyEventsByID.merge(newEntries) { _, new in new }
            })
            .store(in: &cancellables)
    }
    
    private func buildLayouts(from results: [(Date, [CalendarEvent])]) {
        let cal = Calendar.current

        // 이벤트별 날짜 집합 구성
        var eventDatesMap: [String: (CalendarEvent, Set<Date>)] = [:]
        for (date, events) in results {
            let key = cal.startOfDay(for: date)
            for event in events {
                if eventDatesMap[event.id] == nil {
                    eventDatesMap[event.id] = (event, [key])
                } else {
                    eventDatesMap[event.id]!.1.insert(key)
                }
            }
        }

        // 월 전체 이벤트 캐시 갱신 (pill 탭 → 상세 조회용)
        allEventsInMonth = eventDatesMap.mapValues { $0.0 }
        
        var barsDict: [Date: [EventBarInfo]] = [:]
        for (id, (event, dates)) in eventDatesMap {
            let sorted = dates.sorted()
            for date in sorted {
                let pos: BarPosition
                if sorted.count <= 1 { pos = .single }
                else if date == sorted.first { pos = .start }
                else if date == sorted.last { pos = .end }
                else { pos = .middle }
                barsDict[date, default: []].append(
                    EventBarInfo(id: id, colorHex: event.calendarColorHex, position: pos)
                )
            }
        }
        for key in barsDict.keys {
            barsDict[key] = Array((barsDict[key] ?? []).prefix(3))
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            eventBarsPerDate = barsDict
        }

        // 주간 레이아웃 계산
        var newWeekLayouts: [Date: [CalendarEventLayout]] = [:]
        
        for (weekIndex, week) in weeksInMonth.enumerated() {
            let weekSunday = weekStart(for: weekIndex)
            let weekSaturday = cal.date(byAdding: .day, value: 6, to: weekSunday)!
            let wsKey = cal.startOfDay(for: weekSunday)

            var weekDateSet = Set<Date>()
            var colMap: [Date: Int] = [:]
            for (col, optDate) in week.enumerated() {
                if let d = optDate {
                    let key = cal.startOfDay(for: d)
                    weekDateSet.insert(key)
                    colMap[key] = col
                }
            }
            guard !weekDateSet.isEmpty else { continue }

            // 이 주에 걸치는 이벤트 수집 (isActualStart/End를 날짜 비교로 판단)
            var weekEvents: [(CalendarEvent, Int, Int, Bool, Bool)] = []
            for (_, (event, dates)) in eventDatesMap {
                let inWeek = dates.filter { weekDateSet.contains($0) }.sorted()
                guard !inWeek.isEmpty else { continue }

                let allDates = (eventDatesMap[event.id]?.1 ?? []).sorted()
                let isStart = allDates.first.map { cal.startOfDay(for: $0) >= wsKey } ?? true
                let isEnd = allDates.last.map { cal.startOfDay(for: $0) <= cal.startOfDay(for: weekSaturday) } ?? true

                let sc = colMap[inWeek.first!] ?? 0
                let ec = colMap[inWeek.last!] ?? 6
                // displaySettings 오버라이드 적용 (Apple/Google priority·isPinned 반영)
                let applied = event.applying(displaySettingsByID[event.id])
                weekEvents.append((applied, sc, ec, isStart, isEnd))
            }

            // 핀 → 우선순위 → 스팬 순 정렬 (높을수록 위 row에 배치)
            weekEvents.sort { a, b in
                if a.0.isPinned != b.0.isPinned { return a.0.isPinned }
                let pa = a.0.priority == 0 ? Int.max : a.0.priority
                let pb = b.0.priority == 0 ? Int.max : b.0.priority
                if pa != pb { return pa < pb }
                let spanA = a.2 - a.1, spanB = b.2 - b.1
                if spanA != spanB { return spanA > spanB }
                if a.1 != b.1 { return a.1 < b.1 }
                return a.0.title < b.0.title
            }

            // 탐욕 행 배정
            let maxRows = 6
            var occupied = Array(repeating: Array(repeating: false, count: 7), count: maxRows)
            var layouts: [CalendarEventLayout] = []

            for (event, sc, ec, isStart, isEnd) in weekEvents {
                var assignedRow = maxRows - 1
                for r in 0..<maxRows {
                    if (sc...ec).allSatisfy({ !occupied[r][$0] }) { assignedRow = r; break }
                }
                for col in sc...ec { occupied[assignedRow][col] = true }

                layouts.append(CalendarEventLayout(
                    id: event.id, title: event.title, colorHex: event.calendarColorHex,
                    source: event.source,
                    startCol: sc, endCol: ec, row: assignedRow,
                    isActualStart: isStart, isActualEnd: isEnd,
                    isPinned: event.isPinned,
                    priority: event.priority
                ))
            }

            newWeekLayouts[wsKey] = layouts
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            weekLayouts = newWeekLayouts
        }
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
                
                // 신규 등록 시: 일정 시작일로 포커스 이동
                if self.eventToEdit == nil {
                    let cal = Calendar.current
                    self.selectedDate = event.startDate
                    // 등록된 일정이 현재 표시 월과 다르면 월도 이동
                    if !cal.isDate(event.startDate, equalTo: self.currentMonth, toGranularity: .month) {
                        self.currentMonth = event.startDate
                    }
                    self.showSuccessAnimation = true
                }
                
                self.fetchEventsForDate(self.selectedDate)
                self.fetchEventsForMonth()
                self.cancelNotificationUseCase.execute(identifier: event.id)
                if event.notificationMinutesBefore >= 0 {
                    self.scheduleNotificationUseCase.execute(for: event)
                }
            }).store(in: &cancellables)
    }
    
    func requestDelete(_ event: CalendarEvent) {
        if event.source == .dozy {
            guard let dozy = dozyEventsByID[event.id] else { return }
            pendingDeleteEvent = dozy
        } else {
            pendingDeleteCalendarEvent = event
        }
        showDeleteAlert = true
    }

    func deleteEvent(_ event: DozyEvent) {
        cancelNotificationUseCase.execute(identifier: event.id)
        deleteEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.showEventDetail = false
                self.showDeleteSuccess = true
                self.fetchEventsForDate(self.selectedDate)
                self.fetchEventsForMonth()
            }).store(in: &cancellables)
    }
    
    // MARK: - Memo
    func saveMemos(for event: DozyEvent) {
        updateEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }
}
