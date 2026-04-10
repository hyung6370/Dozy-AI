//
//  HomeViewModel.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//
//  [Clean Architecture - MVVM]
//  ViewModel은 UseCase만 사용합니다.
//  Service나 Repository를 직접 참조하지 않습니다.

import Foundation
import Combine

final class HomeViewModel: ObservableObject {

    // MARK: - Published State

    @Published var todayEvents: [CalendarEvent] = []
    @Published var completionsByEventID: [String: Bool] = [:]
    @Published var completedTasks: [TaskItem] = []
    @Published var pendingTasks: [TaskItem] = []
    @Published var todayLog: WorkLog?
    @Published var recentLogs: [WorkLog] = []

    @Published var dailySummary: DailySummary?
    @Published var isSummarizing = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false
    
    @Published var selectedSource: CalendarSource? = nil
    
    @Published var selectedTab: HomeTab = .today
    @Published var weeklyEvents: [[CalendarEvent]] = []
    @Published var weeklyDates: [Date] = []
    @Published var monthlySummary: MonthlySummary? = nil
    @Published var dozyEventsByID: [String: DozyEvent] = [:]

    // MARK: - Computed Properties

    var todayDateString: String { Date().formattedKorean }
    var eventCount: Int { todayEvents.count }
    var completedCount: Int { todayEvents.filter { completionsByEventID[$0.id] == true }.count }
    var pendingCount: Int { todayEvents.filter { completionsByEventID[$0.id] != true }.count }

    var hasData: Bool {
        !todayEvents.isEmpty || !completedTasks.isEmpty
    }

    var hasSummary: Bool {
        dailySummary != nil || !(todayLog?.aiSummary.isEmpty ?? true)
    }

    var scorePercentage: Int {
        guard let score = dailySummary?.productivityScore else { return 0 }
        return Int(score * 100)
    }
    
    // 활성 소스가 2개 이상일 때만 탭 표시
    var showSourceTabs: Bool {
        calendarSourceManager.enabledSources.count > 1
    }
    
    // 활성화된 소스 목록 (탭 생성용)
    var availableSources: [CalendarSource] {
        CalendarSource.allCases.filter { calendarSourceManager.isEnabled($0) }
    }
    
    // 선택된 탭에 따라 필터링
    var filteredEvents: [CalendarEvent] {
        guard let source = selectedSource else { return todayEvents }
        return todayEvents.filter { $0.source == source }
    }
    
    var currentWeekRange: String {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)
        else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: Date())
    }
    
    private let calendarSourceManager: CalendarSourceManager
    private let googleSignInService: GoogleSignInService

    // MARK: - Dependencies (UseCases만)

    private let fetchTodayDataUseCase: FetchTodayDataUseCase
    private let saveWorkLogUseCase: SaveWorkLogUseCase
    private let generateDailySummaryUseCase: GenerateDailySummaryUseCase
    private let fetchRecentLogsUseCase: FetchRecentLogsUseCase
    private let fetchCalendarEventUseCase: FetchCalendarEventUseCase
    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let fetchEventCompletionsUseCase: FetchEventCompletionsUseCase
    private let deleteDozyEventUseCase: DeleteDozyEventUseCase
    private let deleteCalendarEventUseCase: DeleteCalendarEventUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let updateCalendarEventUseCase: UpdateCalendarEventUseCase
    private let displaySettingsRepo: EventDisplaySettingsRepository
    var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        fetchTodayDataUseCase: FetchTodayDataUseCase,
        saveWorkLogUseCase: SaveWorkLogUseCase,
        generateDailySummaryUseCase: GenerateDailySummaryUseCase,
        fetchRecentLogsUseCase: FetchRecentLogsUseCase,
        calendarSourceManager: CalendarSourceManager,
        googleSignInService: GoogleSignInService,
        fetchCalendarEventUseCase: FetchCalendarEventUseCase,
        fetchDozyEventsUseCase: FetchDozyEventsUseCase,
        fetchEventCompletionsUseCase: FetchEventCompletionsUseCase,
        deleteDozyEventUseCase: DeleteDozyEventUseCase,
        deleteCalendarEventUseCase: DeleteCalendarEventUseCase,
        updateDozyEventUseCase: UpdateDozyEventUseCase,
        updateCalendarEventUseCase: UpdateCalendarEventUseCase,
        displaySettingsRepo: EventDisplaySettingsRepository
    ) {
        self.fetchTodayDataUseCase = fetchTodayDataUseCase
        self.saveWorkLogUseCase = saveWorkLogUseCase
        self.generateDailySummaryUseCase = generateDailySummaryUseCase
        self.fetchRecentLogsUseCase = fetchRecentLogsUseCase
        self.calendarSourceManager = calendarSourceManager
        self.googleSignInService = googleSignInService
        self.fetchCalendarEventUseCase = fetchCalendarEventUseCase
        self.fetchDozyEventsUseCase = fetchDozyEventsUseCase
        self.fetchEventCompletionsUseCase = fetchEventCompletionsUseCase
        self.deleteDozyEventUseCase = deleteDozyEventUseCase
        self.deleteCalendarEventUseCase = deleteCalendarEventUseCase
        self.updateDozyEventUseCase = updateDozyEventUseCase
        self.updateCalendarEventUseCase = updateCalendarEventUseCase
        self.displaySettingsRepo = displaySettingsRepo
        
        googleSignInService.$isSignedIn
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadTodayData()
            }
            .store(in: &cancellables)
        
        calendarSourceManager.$enabledSources
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sources in
                guard let self else { return }
                if let selected = self.selectedSource, !sources.contains(selected) {
                    self.selectedSource = nil
                }
                self.loadTodayData()
            }
            .store(in: &cancellables)
    }

    convenience init(container: DependencyContainer) {
        self.init(
            fetchTodayDataUseCase: container.fetchTodayDataUseCase,
            saveWorkLogUseCase: container.saveWorkLogUseCase,
            generateDailySummaryUseCase: container.generateDailySummaryUseCase,
            fetchRecentLogsUseCase: container.fetchRecentLogsUseCase,
            calendarSourceManager: container.calendarSourceManager,
            googleSignInService: container.googleSignInService,
            fetchCalendarEventUseCase: container.fetchCalendarEventUseCase,
            fetchDozyEventsUseCase: container.fetchDozyEventsUseCase,
            fetchEventCompletionsUseCase: container.fetchEventCompletionsUseCase,
            deleteDozyEventUseCase: container.deleteDozyEventUseCase,
            deleteCalendarEventUseCase: container.deleteCalendarEventUseCase,
            updateDozyEventUseCase: container.updateDozyEventUseCase,
            updateCalendarEventUseCase: container.updateCalendarEventUseCase,
            displaySettingsRepo: container.eventDisplaySettingsRepository
        )
    }

    // MARK: - 데이터 로드

    func loadTodayData() {
        isLoading = true
        errorMessage = nil

        fetchTodayDataUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] result in
                    guard let self else { return }
                    self.todayEvents = result.events
                    self.completedTasks = result.completedTasks
                    self.pendingTasks = result.pendingTasks
                    self.persistTodayLog(events: result.events, tasks: result.completedTasks)
                    self.loadCompletions(for: result.events)
                }
            )
            .store(in: &cancellables)

        loadRecentLogs()
        loadWeeklyData()
        loadMonthlyData()
    }

    private func loadCompletions(for events: [CalendarEvent]) {
        let allIDs = events.map { $0.id }
        let dozyIDs = Set(events.filter { $0.source == .dozy }.map { $0.id })

        Publishers.Zip(
            fetchDozyEventsUseCase.execute(for: Date()),
            fetchEventCompletionsUseCase.execute(for: allIDs)
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] dozyEvents, completionsMap in
            guard let self else { return }
            var merged: [String: Bool] = completionsMap
            var dict: [String: DozyEvent] = [:]
            for event in dozyEvents {
                dict[event.id] = event
                if dozyIDs.contains(event.id) {
                    merged[event.id] = event.isCompleted
                }
            }
            self.dozyEventsByID = dict
            self.completionsByEventID = merged
        })
        .store(in: &cancellables)
    }

    func loadRecentLogs() {
        fetchRecentLogsUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] logs in
                    self?.recentLogs = logs
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 메모

    func addMemo(_ text: String) {
        guard let log = todayLog else { return }
        saveWorkLogUseCase.addMemo(text, to: log)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    func updateMemo(at index: Int, text: String) {
        guard let log = todayLog else { return }
        saveWorkLogUseCase.updateMemo(at: index, text: text, in: log)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    func deleteMemo(at index: Int) {
        guard let log = todayLog else { return }
        saveWorkLogUseCase.deleteMemo(at: index, in: log)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    // MARK: - AI 요약 생성

    func generateAISummary() {
        guard hasData else {
            errorMessage = "요약할 데이터가 부족합니다."
            return
        }

        isSummarizing = true
        errorMessage = nil

        generateDailySummaryUseCase.execute(
            events: todayEvents,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            memos: todayLog?.memos ?? [],
            completedEventCount: completedCount
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isSummarizing = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            },
            receiveValue: { [weak self] summary in
                self?.dailySummary = summary
            }
        )
        .store(in: &cancellables)
    }
    
    func loadWeeklyData() {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else { return }
        
        var dates: [Date] = []
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: weekStart) {
                dates.append(day)
            }
        }
        weeklyDates = dates
        
        let publishers = dates.map { date in
            fetchCalendarEventUseCase.execute(for: date)
                .replaceError(with: [])
        }
        
        Publishers.MergeMany(publishers.enumerated().map { index, pub in
            pub.map { (index, $0) }
        })
        .collect()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] results in
            guard let self else { return }
            var buckets: [[CalendarEvent]] = Array(repeating: [], count: dates.count)
            for (index, events) in results {
                buckets[index] = events
            }
            self.weeklyEvents = buckets
        }
        .store(in: &cancellables)
    }
    
    func loadMonthlyData() {
        // Phase 5 패턴 분석과 연계 예정
        // 현재는 recentLogs 기반으로 간단히 집계
        let logs = recentLogs
        let totalScore = logs.compactMap { $0.productivityScore }.reduce(0, +)
        let avg = logs.isEmpty ? 0.0 : totalScore / Double(logs.count)
        
        monthlySummary = MonthlySummary(
            totalEvents: logs.reduce(0) { $0 + $1.rawEventTitles.count },
            totalCompletedTasks: logs.reduce(0) { $0 + $1.completedTaskTitles.count },
            averageProductivityScore: avg,
            activeDays: logs.count
        )
    }

    // MARK: - Private

    /// 오늘 WorkLog를 생성/업데이트하고 AI 요약이 있으면 복원합니다
    private func persistTodayLog(events: [CalendarEvent], tasks: [TaskItem]) {
        saveWorkLogUseCase.execute(events: events, tasks: tasks)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] log in
                    guard let self else { return }
                    self.todayLog = log
                    // 저장된 AI 요약이 있으면 복원
                    if !log.aiSummary.isEmpty {
                        self.restoreSummaryFromLog(log)
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func restoreSummaryFromLog(_ log: WorkLog) {
        let totalMinutes = todayEvents
            .filter { !$0.isAllDay }
            .reduce(0) { $0 + $1.durationMinutes }

        dailySummary = DailySummary(
            date: log.date,
            summaryText: log.aiSummary,
            highlights: log.highlights,
            nextActions: log.nextActions,
            detectedCategory: log.category,
            productivityScore: log.productivityScore ?? 0.0,
            totalEventMinutes: totalMinutes,
            completedTaskCount: log.completedTaskTitles.count
        )
    }

    private func handleError(_ error: DozyError) {
        switch error {
        case .calendarAccessDenied, .reminderAccessDenied:
            showPermissionAlert = true
            errorMessage = error.errorDescription
        default:
            errorMessage = error.errorDescription
        }
    }

    // MARK: - Event Detail Actions

    func saveDozyEvent(_ event: DozyEvent) {
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func saveCalendarEvent(_ event: CalendarEvent, edit: CalendarEventEditRequest) {
        updateCalendarEventUseCase.execute(event, with: edit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func saveMemos(for dozyEvent: DozyEvent) {
        updateDozyEventUseCase.execute(dozyEvent)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    func deleteDozyEvent(_ dozyEvent: DozyEvent) {
        deleteDozyEventUseCase.execute(dozyEvent)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func deleteThisOccurrence(_ dozyEvent: DozyEvent, date: Date) {
        let occStart = dozyEvent.occurrenceStart(for: date) ?? Calendar.current.startOfDay(for: date)
        dozyEvent.excludedDates.append(occStart)
        dozyEvent.updatedAt = Date()
        updateDozyEventUseCase.execute(dozyEvent)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func deleteFutureOccurrences(_ dozyEvent: DozyEvent, from date: Date) {
        let cal = Calendar.current
        dozyEvent.recurrenceEndDate = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))!
        dozyEvent.updatedAt = Date()
        updateDozyEventUseCase.execute(dozyEvent)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func deleteCalendarEvent(_ event: CalendarEvent) {
        deleteCalendarEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func updateDisplaySettings(for event: CalendarEvent, priority: Int, isPinned: Bool, category: String?) {
        if event.source == .dozy {
            guard let dozy = dozyEventsByID[event.id] else { return }
            dozy.priority = priority
            dozy.isPinned = isPinned
            if let category { dozy.category = category }
            updateDozyEventUseCase.execute(dozy)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                    self?.loadTodayData()
                })
                .store(in: &cancellables)
        } else {
            let finalCategory = category ?? event.category
            displaySettingsRepo.save(eventID: event.id, priority: priority, isPinned: isPinned, category: finalCategory)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                    self?.loadTodayData()
                })
                .store(in: &cancellables)
        }
    }
}
