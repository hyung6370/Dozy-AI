//
//  CalendarViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine
import SwiftUI
import OSLog

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
    let id: String       // ForEach 고유 키 (eventId + 위치 조합 — 반복 일정 중복 방지)
    let eventId: String  // 실제 이벤트 ID (탭·삭제에 사용)
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
    private var loadedMonthKeys = Set<Date>()
    
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
    private let fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase
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
        fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase,
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
        self.fetchCalendarEventsForPeriodUseCase = fetchCalendarEventsForPeriodUseCase
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
            fetchCalendarEventsForPeriodUseCase: container.fetchCalendarEventsForPeriodUseCase,
            displaySettingsRepo: container.eventDisplaySettingsRepository
        )
        self.calendarService = container.calendarService

        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Logger.calendar.info("🔔 dozyDataSyncCompleted 수신 → loadInitialData 재실행")
                self?.loadedMonthKeys.removeAll()
                self?.loadInitialData()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .googleSignInRestored)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Logger.calendar.info("🔔 googleSignInRestored 수신 → 구글 캘린더 새로고침")
                self?.refreshData()
            }
            .store(in: &cancellables)
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

    func weeksFor(month: Date) -> [[Date]] {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let weekday = cal.component(.weekday, from: first) - 1
        let range = cal.range(of: .day, in: .month, for: month)!
        var days: [Date] = []
        for i in 0..<weekday {
            days.append(cal.date(byAdding: .day, value: i - weekday, to: first)!)
        }
        for day in range {
            var comps = cal.dateComponents([.year, .month], from: month)
            comps.day = day
            days.append(cal.date(from: comps)!)
        }
        var extra = 1
        while days.count % 7 != 0 {
            days.append(cal.date(byAdding: .day, value: range.count - 1 + extra, to: first)!)
            extra += 1
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0+7]) }
    }

    func weekStartDate(weekIndex: Int, month: Date) -> Date {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let weekday = cal.component(.weekday, from: first) - 1
        let displayStart = cal.date(byAdding: .day, value: -weekday, to: first)!
        return cal.date(byAdding: .day, value: weekIndex * 7, to: displayStart)!
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
        // 항상 displaySettings를 적용 (allEventsInMonth 등 raw 이벤트에서 올 수 있음)
        let applied = event.applying(displaySettingsByID[event.id])
        Logger.calendar.debug("📋 showDetail: id=\(event.id.prefix(12)) category=\(applied.category) source=\(String(describing: event.source))")
        detailEvent = applied
        showEventDetail = true
    }

    func showDetailForEventID(_ id: String, on occurrenceDate: Date? = nil) {
        // 반복 DozyEvent의 특정 날짜 인스턴스를 직접 재구성 (비동기 fetch 없이 즉시 조회)
        if let date = occurrenceDate,
           let dozy = dozyEventsByID[id],
           dozy.occursOn(date) {
            let event = dozy.toCalendarEvent(for: date).applying(displaySettingsByID[id])
            showDetail(for: event)
            return
        }
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
    
    private func completionKey(for event: CalendarEvent) -> String {
        EventCompletionRepository.completionKey(eventID: event.id, date: event.startDate)
    }

    // 완료 상태 통합 조회
    func isCompleted(for event: CalendarEvent) -> Bool {
        if event.source == .dozy {
            let dozy = dozyEventsByID[event.id]
            // 반복 일정은 날짜별 완료 체크 (EventCompletion 사용)
            if let dozy, dozy.recurrenceRule != "none" {
                return completionsByID[completionKey(for: event)] ?? false
            }
            return dozy?.isCompleted ?? false
        }
        return completionsByID[completionKey(for: event)] ?? false
    }

    // 완료 토글 (source 분기)
    func toggleCompletion(for event: CalendarEvent) {
        if event.source == .dozy {
            guard let dozyEvent = dozyEventsByID[event.id] else { return }
            // 반복 일정은 날짜별 독립 완료 (EventCompletion 사용)
            if dozyEvent.recurrenceRule != "none" {
                toggleCalendarEventCompletionUseCase.execute(eventID: event.id, eventDate: event.startDate)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newValue in
                        guard let self else { return }
                        self.completionsByID[self.completionKey(for: event)] = newValue
                    })
                    .store(in: &cancellables)
            } else {
                toggleCompletion(for: dozyEvent)
            }
        } else {
            toggleCalendarEventCompletionUseCase.execute(eventID: event.id, eventDate: event.startDate)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newValue in
                    guard let self else { return }
                    self.completionsByID[self.completionKey(for: event)] = newValue
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
                self?.fetchEventsForMonth(force: true)
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
                            self.weekLayouts[key]?.removeAll { $0.eventId == event.id }
                        }
                        for key in self.eventBarsPerDate.keys {
                            self.eventBarsPerDate[key]?.removeAll { $0.id == event.id }
                        }
                    }
                    // EventKit 동기화 후 재조회
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        self?.fetchEventsForDate(self?.selectedDate ?? Date())
                        self?.fetchEventsForMonth(force: true)
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
    
    func setCurrentMonth(_ date: Date) {
        currentMonth = date
        fetchEventsForMonth()
    }

    func jumpToMonth(year: Int, month: Int) {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return }
        currentMonth = date
        fetchEventsForMonth()
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
        loadedMonthKeys.removeAll()
        loadInitialData()
    }
    
    private func fetchEventsForDate(_ date: Date, showLoading: Bool = true) {
        if showLoading { isLoading = true }
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

                // Apple/Google + Dozy 반복 일정 completion 조회
                let nonDozyIDs = events.filter { $0.source != .dozy }.map { $0.id }
                let recurringDozyIDs = dozyEvents.filter { $0.recurrenceRule != "none" }.map { $0.id }
                let allCompletionIDs = nonDozyIDs + recurringDozyIDs
                if !allCompletionIDs.isEmpty {
                    self.fetchEventCompletionsUseCase.execute(for: allCompletionIDs, on: date)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { _ in }, receiveValue: { dict in
                            self.completionsByID.merge(dict) { _, new in new }
                        })
                        .store(in: &self.cancellables)
                }

                // Apple/Google 이벤트에 display settings 오버라이드 적용 후 정렬
                Logger.calendar.debug("🔄 fetchEventsForDate → fetchAll(for: \(nonDozyIDs.count)건)")
                self.displaySettingsRepo.fetchAll(for: nonDozyIDs)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] settings in
                        guard let self else { return }
                        Logger.calendar.debug("🔄 fetchAll 결과: \(settings.count)건")
                        for (id, s) in settings {
                            Logger.calendar.debug("   ↳ id=\(id.prefix(12)) category=\(s.category)")
                        }
                        self.displaySettingsByID.merge(settings) { _, new in new }
                        let applied = events.map { $0.applying(self.displaySettingsByID[$0.id]) }
                        for e in applied where e.source == .google {
                            Logger.calendar.debug("🔄 applied: id=\(e.id.prefix(12)) title=\(e.title) category=\(e.category)")
                        }
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

    func updateDisplaySettings(for event: CalendarEvent, priority: Int, isPinned: Bool, category: String? = nil) {
        if event.source == .dozy {
            guard let dozy = dozyEventsByID[event.id] else { return }
            dozy.priority = priority
            dozy.isPinned = isPinned
            if let category { dozy.category = category }
            updateEventUseCase.execute(dozy)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                    self?.fetchEventsForDate(self?.selectedDate ?? Date())
                    self?.fetchEventsForMonth(force: true)
                })
                .store(in: &cancellables)
        } else {
            let finalCategory = category ?? event.category
            Logger.calendar.debug("⚙️ updateDisplaySettings(non-dozy): id=\(event.id.prefix(12)) finalCategory=\(finalCategory) priority=\(priority) isPinned=\(isPinned)")

            // 1) eventsForSelectedDate 즉시 갱신 (SwiftData @Model 우회 — 직접 CalendarEvent 생성)
            if let idx = eventsForSelectedDate.firstIndex(where: { $0.id == event.id }) {
                let old = eventsForSelectedDate[idx]
                eventsForSelectedDate[idx] = CalendarEvent(
                    id: old.id, calendarId: old.calendarId, title: old.title,
                    startDate: old.startDate, endDate: old.endDate,
                    location: old.location, notes: old.notes, isAllDay: old.isAllDay,
                    calendarName: old.calendarName, calendarColorHex: old.calendarColorHex,
                    source: old.source,
                    priority: priority, isPinned: isPinned, category: finalCategory
                )
                Logger.calendar.debug("⚙️ eventsForSelectedDate[\(idx)] updated → category=\(finalCategory)")
            } else {
                Logger.calendar.warning("⚠️ eventsForSelectedDate에서 event.id=\(event.id.prefix(12))를 찾지 못함")
            }

            // 2) 기존 displaySettings가 있으면 인메모리도 갱신 (이후 fetchEventsForDate 시 applying 정합성)
            if let settings = displaySettingsByID[event.id] {
                settings.priority = priority
                settings.isPinned = isPinned
                settings.category = finalCategory
                Logger.calendar.debug("⚙️ displaySettingsByID 갱신 완료")
            } else {
                Logger.calendar.debug("⚙️ displaySettingsByID에 기존 항목 없음 (첫 저장)")
            }

            // 3) DB 저장 → 저장 후 fetch해서 displaySettingsByID 동기화
            let eventID = event.id
            displaySettingsRepo.save(
                eventID: eventID,
                priority: priority,
                isPinned: isPinned,
                category: finalCategory
            )
            .flatMap { [displaySettingsRepo] _ -> AnyPublisher<[String: EventDisplaySettings], Never> in
                Logger.calendar.debug("⚙️ DB save 완료 → fetchAll 시작")
                return displaySettingsRepo.fetchAll(for: [eventID])
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self else { return }
                self.displaySettingsByID.merge(settings) { _, new in new }
                Logger.calendar.debug("⚙️ displaySettingsByID 동기화 완료: \(settings[eventID]?.category ?? "nil")")
            }
            .store(in: &cancellables)
        }
    }
    
    private func fetchEventsForMonth(_ month: Date? = nil, force: Bool = false) {
        let cal = Calendar.current
        let targetMonth = month ?? currentMonth
        guard let interval = cal.dateInterval(of: .month, for: targetMonth) else { return }

        let monthKey = cal.date(from: cal.dateComponents([.year, .month], from: targetMonth))!
        guard force || !loadedMonthKeys.contains(monthKey) else { return }

        // 표시 범위 확장 (첫째 주/마지막 주 이전달, 다음달 날짜 포함)
        let firstWeekday = cal.component(.weekday, from: interval.start) - 1
        let displayStart = cal.date(byAdding: .day, value: -firstWeekday, to: interval.start)!

        let lastDay = cal.date(byAdding: .day, value: -1, to: interval.end)!
        let lastWeekday = cal.component(.weekday, from: lastDay) - 1
        let displayEnd = cal.date(byAdding: .day, value: 7 - lastWeekday, to: lastDay)!

        fetchCalendarEventsForPeriodUseCase.execute(from: displayStart, to: displayEnd)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] events in
                guard let self else { return }
                let results = self.groupEventsByDate(events, from: displayStart, to: displayEnd)
                self.buildLayouts(from: results, forMonth: targetMonth)
                self.loadedMonthKeys.insert(monthKey)
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

        // 인접 달 미리 로드 (현재 달 탐색 시에만)
        if month == nil {
            prefetchAdjacentMonths()
        }
    }

    private func prefetchAdjacentMonths() {
        let cal = Calendar.current
        for offset in [-1, 1] {
            if let adjMonth = cal.date(byAdding: .month, value: offset, to: currentMonth) {
                fetchEventsForMonth(adjMonth)
            }
        }
    }
    
    private func groupEventsByDate(_ events: [CalendarEvent], from start: Date, to end: Date) -> [(Date, [CalendarEvent])] {
        let cal = Calendar.current
        var result: [(Date, [CalendarEvent])] = []
        var date = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while date < endDay {
            let nextDate = cal.date(byAdding: .day, value: 1, to: date)!
            let dayEvents = events.filter { ev in
                // all-day 이벤트는 endDate == startDate (Dozy 저장 방식: finalEnd = isAllDay ? startDate : endDate)
                // midnight > midnight = false 가 되어 필터링됨 → effectiveEnd를 다음날 자정으로 보정
                let effectiveEnd: Date
                if ev.isAllDay, cal.startOfDay(for: ev.endDate) <= cal.startOfDay(for: ev.startDate) {
                    effectiveEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: ev.startDate))!
                } else {
                    effectiveEnd = ev.endDate
                }
                return ev.startDate < nextDate && effectiveEnd > date
            }
            result.append((date, dayEvents))
            date = nextDate
        }
        return result
    }

    private func buildLayouts(from results: [(Date, [CalendarEvent])], forMonth month: Date) {
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
        allEventsInMonth.merge(eventDatesMap.mapValues { $0.0 }) { _, new in new }
        
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
            eventBarsPerDate.merge(barsDict) { _, new in new }
        }

        // 주간 레이아웃 계산 (forMonth 기준 주 배열 로컬 계산)
        let monthFirst = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let firstWeekdayOffset = cal.component(.weekday, from: monthFirst) - 1
        let monthDisplayStart = cal.date(byAdding: .day, value: -firstWeekdayOffset, to: monthFirst)!
        let monthRange = cal.range(of: .day, in: .month, for: month)!
        // 이전달 날짜도 실제 Date로 채워 인접 달 이벤트가 레이아웃에 포함되게 함
        var monthDays: [Date] = (0..<firstWeekdayOffset).map {
            cal.date(byAdding: .day, value: $0 - firstWeekdayOffset, to: monthFirst)!
        }
        for day in monthRange {
            var comps = cal.dateComponents([.year, .month], from: month)
            comps.day = day
            monthDays.append(cal.date(from: comps)!)
        }
        var extra = 1
        while monthDays.count % 7 != 0 {
            monthDays.append(cal.date(byAdding: .day, value: monthRange.count - 1 + extra, to: monthFirst)!)
            extra += 1
        }
        let weeksForMonth = stride(from: 0, to: monthDays.count, by: 7).map { Array(monthDays[$0..<$0+7]) }

        var newWeekLayouts: [Date: [CalendarEventLayout]] = [:]

        // 반복 일정은 연속 날짜 그룹별로 분리 (예: 매주 월요일 → 각 월요일이 독립 스팬)
        var segmentedEvents: [(CalendarEvent, Set<Date>)] = []
        for (_, (event, dates)) in eventDatesMap {
            // 단일 날짜 이벤트(당일 종료)가 여러 날에 걸쳐 있으면 반복 인스턴스이므로 각 날을 독립 세그먼트로
            let isSingleDayEvent: Bool
            if event.isAllDay {
                let dayDiff = cal.dateComponents([.day], from: cal.startOfDay(for: event.startDate),
                                                 to: cal.startOfDay(for: event.endDate)).day ?? 0
                isSingleDayEvent = dayDiff <= 1
            } else {
                isSingleDayEvent = cal.isDate(event.startDate, inSameDayAs: event.endDate)
            }
            if isSingleDayEvent && dates.count > 1 {
                for date in dates { segmentedEvents.append((event, [date])) }
                continue
            }

            let sorted = dates.sorted()
            var currentGroup: [Date] = []
            for date in sorted {
                if let last = currentGroup.last,
                   let next = cal.date(byAdding: .day, value: 1, to: last),
                   cal.startOfDay(for: next) == cal.startOfDay(for: date) {
                    currentGroup.append(date)
                } else {
                    if !currentGroup.isEmpty {
                        segmentedEvents.append((event, Set(currentGroup)))
                    }
                    currentGroup = [date]
                }
            }
            if !currentGroup.isEmpty {
                segmentedEvents.append((event, Set(currentGroup)))
            }
        }

        for (weekIndex, week) in weeksForMonth.enumerated() {
            let weekSunday = cal.date(byAdding: .day, value: weekIndex * 7, to: monthDisplayStart)!
            let weekSaturday = cal.date(byAdding: .day, value: 6, to: weekSunday)!
            let wsKey = cal.startOfDay(for: weekSunday)

            var weekDateSet = Set<Date>()
            var colMap: [Date: Int] = [:]
            for (col, date) in week.enumerated() {
                let key = cal.startOfDay(for: date)
                weekDateSet.insert(key)
                colMap[key] = col
            }

            // 이 주에 걸치는 이벤트 수집 (세그먼트 단위로 isActualStart/End 판단)
            var weekEvents: [(CalendarEvent, Int, Int, Bool, Bool)] = []
            for (event, segmentDates) in segmentedEvents {
                let inWeek = segmentDates.filter { weekDateSet.contains($0) }.sorted()
                guard !inWeek.isEmpty else { continue }

                let allDates = segmentDates.sorted()
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
                    id: "\(event.id)_\(sc)_\(assignedRow)",
                    eventId: event.id,
                    title: event.title, colorHex: event.calendarColorHex,
                    source: event.source,
                    startCol: sc, endCol: ec, row: assignedRow,
                    isActualStart: isStart, isActualEnd: isEnd,
                    isPinned: event.isPinned,
                    priority: event.priority
                ))
            }

            newWeekLayouts[wsKey] = layouts
        }
        weekLayouts.merge(newWeekLayouts) { _, new in new }
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
                
                self.fetchEventsForDate(self.selectedDate, showLoading: false)
                self.fetchEventsForMonth(force: true)
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
                self.fetchEventsForDate(self.selectedDate, showLoading: false)
                self.fetchEventsForMonth(force: true)
            }).store(in: &cancellables)
    }

    /// 이 일정만 삭제 — 해당 인스턴스의 시작일을 제외 목록에 추가
    func deleteThisOccurrence(_ event: DozyEvent, date: Date) {
        let occStart = event.occurrenceStart(for: date) ?? Calendar.current.startOfDay(for: date)
        event.excludedDates.append(occStart)
        event.updatedAt = Date()
        updateEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.showEventDetail = false
                self.showDeleteSuccess = true
                self.fetchEventsForDate(self.selectedDate, showLoading: false)
                self.fetchEventsForMonth(force: true)
            }).store(in: &cancellables)
    }

    /// 이후 모든 일정 삭제 — recurrenceEndDate를 해당 날짜 전날로 설정
    func deleteFutureOccurrences(_ event: DozyEvent, from date: Date) {
        let cal = Calendar.current
        let previousDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))!
        event.recurrenceEndDate = previousDay
        event.updatedAt = Date()
        updateEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                self.showEventDetail = false
                self.showDeleteSuccess = true
                self.fetchEventsForDate(self.selectedDate, showLoading: false)
                self.fetchEventsForMonth(force: true)
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
