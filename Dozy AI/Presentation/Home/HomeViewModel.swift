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
import SwiftData
import WidgetKit

@MainActor
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
    @Published var showSuccessAnimation = false
    @Published var hasNotification = false
    
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
        formatter.locale = .current
        formatter.dateFormat = String(localized: "yyyy년 M월")
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
    /// 위젯의 미니 캘린더 dot 표시용 — 이번 달 일정 전체를 별도 fetch 할 때 사용.
    private let fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase
    /// 메인 fetch 와 분리된 cancellable — 월간 fetch 가 매번 새로 시작.
    private var widgetMonthFetchCancellable: AnyCancellable?
    private let deleteDozyEventUseCase: DeleteDozyEventUseCase
    private let deleteCalendarEventUseCase: DeleteCalendarEventUseCase
    private let createDozyEventUseCase: CreateDozyEventUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let updateCalendarEventUseCase: UpdateCalendarEventUseCase
    private let displaySettingsRepo: EventDisplaySettingsRepository
    private let notificationRepository: NotificationRepository
    /// 위젯 캐시 쓰기용. App Group container 가리키므로 위젯 extension 이 같은 store 를 본다.
    private let modelContainer: ModelContainer
    var cancellables = Set<AnyCancellable>()
    private var todayDataCancellable: AnyCancellable?
    private var completionFetchCancellable: AnyCancellable?

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
        fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase,
        deleteDozyEventUseCase: DeleteDozyEventUseCase,
        deleteCalendarEventUseCase: DeleteCalendarEventUseCase,
        createDozyEventUseCase: CreateDozyEventUseCase,
        updateDozyEventUseCase: UpdateDozyEventUseCase,
        updateCalendarEventUseCase: UpdateCalendarEventUseCase,
        displaySettingsRepo: EventDisplaySettingsRepository,
        notificationRepository: NotificationRepository,
        modelContainer: ModelContainer
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
        self.fetchCalendarEventsForPeriodUseCase = fetchCalendarEventsForPeriodUseCase
        self.deleteDozyEventUseCase = deleteDozyEventUseCase
        self.deleteCalendarEventUseCase = deleteCalendarEventUseCase
        self.createDozyEventUseCase = createDozyEventUseCase
        self.updateDozyEventUseCase = updateDozyEventUseCase
        self.updateCalendarEventUseCase = updateCalendarEventUseCase
        self.displaySettingsRepo = displaySettingsRepo
        self.notificationRepository = notificationRepository
        self.modelContainer = modelContainer
        
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

        NotificationCenter.default.publisher(for: .dozyEventChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadTodayData() }
            .store(in: &cancellables)

        // 파트너 공유 일정 카드 생성 시 알림 뱃지 즉시 갱신
        NotificationCenter.default.publisher(for: .dozyNotificationsChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshNotificationBadge() }
            .store(in: &cancellables)

        // 기본 공유 캘린더 변경 감지 → 오늘 데이터 재로드
        ActiveSharedCalendarStore.shared.$activeCalendarID
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.dozyEventsByID.removeAll()
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
            fetchCalendarEventsForPeriodUseCase: container.fetchCalendarEventsForPeriodUseCase,
            deleteDozyEventUseCase: container.deleteDozyEventUseCase,
            deleteCalendarEventUseCase: container.deleteCalendarEventUseCase,
            createDozyEventUseCase: container.createDozyEventUseCase,
            updateDozyEventUseCase: container.updateDozyEventUseCase,
            updateCalendarEventUseCase: container.updateCalendarEventUseCase,
            displaySettingsRepo: container.eventDisplaySettingsRepository,
            notificationRepository: container.notificationRepository,
            modelContainer: container.modelContainer
        )
    }

    func refreshNotificationBadge() {
        notificationRepository.hasUnread()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.hasNotification = $0 }
            .store(in: &cancellables)
    }

    // MARK: - 데이터 로드

    func loadTodayData() {
        isLoading = true
        errorMessage = nil

        // 단일 cancellable 사용 → 이전 fetch가 느릴 때 새 fetch가 시작되면 이전 구독을 자동 취소
        // (Set<AnyCancellable>에 쌓이면 느린 Google API 응답이 최신 완료 상태를 덮어쓰는 race condition 발생)
        todayDataCancellable = fetchTodayDataUseCase.execute()
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

                    // 위젯 캐시 즉시 갱신 (완료 상태는 default false). 이어 loadCompletions
                    // 가 끝나면 완료 상태 반영된 캐시로 재갱신 — 2단계 update.
                    // 즉시 갱신 이유: completion fetch 가 실패하거나 늦어도 위젯이 최소한
                    // 일정 list 자체는 즉시 표시할 수 있도록.
                    TodayEventCacheWriter.upsert(
                        events: result.events,
                        completions: [:],
                        dozyEventsByID: self.dozyEventsByID,
                        container: self.modelContainer
                    )
                    // Large 위젯의 미니 캘린더에서 일정 있는 날 dot 표시용 — 이번 달
                    // 일정 전체를 별도 fetch 해 dates Set 을 App Group UserDefaults 에 캐싱.
                    self.refreshMonthEventDatesForWidget()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            )

        loadRecentLogs()
        loadWeeklyData()
        loadMonthlyData()
    }

    /// Large 위젯의 미니 캘린더 dot indicator 용 — 이번 달 일정 전체를 fetch 해
    /// 일정 있는 날짜들 (startOfDay) 을 App Group UserDefaults 에 저장.
    /// Today fetch 와 병렬로 동작. 실패해도 위젯 dot 만 안 보이고 다른 동작엔 영향 없음.
    private func refreshMonthEventDatesForWidget() {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: Date()) else { return }

        #if DEBUG
        print("🔄 [Home] refreshMonthEventDatesForWidget 시작: \(interval.start) ~ \(interval.end)")
        #endif

        widgetMonthFetchCancellable = fetchCalendarEventsForPeriodUseCase
            .execute(from: interval.start, to: interval.end)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    #if DEBUG
                    if case .failure(let err) = completion {
                        print("❌ [Home] month fetch 실패: \(err)")
                    }
                    #endif
                },
                receiveValue: { events in
                    #if DEBUG
                    print("✅ [Home] month fetch 완료: \(events.count) events")
                    #endif
                    TodayEventCacheWriter.updateMonthEventDates(events)
                    // dates 만 바뀐 경우에도 위젯 reload — 작은 dot 변화도 즉시 반영.
                    WidgetCenter.shared.reloadAllTimelines()
                }
            )
    }

    private func loadCompletions(for events: [CalendarEvent]) {
        let allIDs = events.map { $0.id }
        let dozyIDs = Set(events.filter { $0.source == .dozy }.map { $0.id })

        // 단일 cancellable 사용 → 이전 완료 fetch가 새 결과를 덮어쓰는 race condition 방지
        completionFetchCancellable = Publishers.Zip(
            fetchDozyEventsUseCase.execute(for: Date()),
            fetchEventCompletionsUseCase.execute(for: allIDs, on: Date())
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] dozyEvents, completionsMap in
            guard let self else { return }
            // completionsMap은 복합키(eventID_timestamp) → event.id 단순키로 역변환
            let today = Date()
            let dayKey = "_\(Int(Calendar.current.startOfDay(for: today).timeIntervalSince1970))"
            var merged: [String: Bool] = [:]
            for (compositeKey, value) in completionsMap {
                let eventID = compositeKey.hasSuffix(dayKey)
                    ? String(compositeKey.dropLast(dayKey.count))
                    : compositeKey
                merged[eventID] = value
            }
            var dict: [String: DozyEvent] = [:]
            for event in dozyEvents {
                dict[event.id] = event
                // Dozy 비반복 일정은 isCompleted 직접 사용
                if dozyIDs.contains(event.id) && event.recurrenceRule == "none" {
                    merged[event.id] = event.isCompleted
                }
            }
            self.dozyEventsByID = dict
            self.completionsByEventID = merged

            // 완료 데이터 로드 후 stored summary 복원 (정확한 completedCount 사용)
            if let log = self.todayLog, !log.aiSummary.isEmpty {
                self.restoreSummaryFromLog(log)
            }

            // 위젯 캐시 갱신 — Apple/Google/Dozy/Holiday 머지된 오늘 일정 + 완료 상태를
            // SwiftData 의 TodayEventCache 로 mirror. 위젯이 다음 reloadAllTimelines() 에서
            // 새 데이터를 읽음.
            TodayEventCacheWriter.upsert(
                events: events,
                completions: merged,
                dozyEventsByID: dict,
                container: self.modelContainer
            )
            WidgetCenter.shared.reloadAllTimelines()
        })
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
            errorMessage = String(localized: "요약할 데이터가 부족합니다.")
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
                    // loadCompletions보다 늦게 완료된 경우를 대비해 여기서도 복원 시도
                    if !log.aiSummary.isEmpty {
                        self.restoreSummaryFromLog(log)
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func restoreSummaryFromLog(_ log: WorkLog) {
        let completedEvents = todayEvents.filter { completionsByEventID[$0.id] == true && !$0.isAllDay }
        let totalMinutes = completedEvents.reduce(0) { $0 + $1.durationMinutes }

        // 현재 completedCount 기반으로 텍스트 재계산 (DB 저장 텍스트 무시)
        let summaryText: String
        if completedCount == 0 {
            summaryText = String(localized: "오늘은 아직 완료된 일정이 없습니다.")
        } else {
            let hours = totalMinutes / 60
            let mins  = totalMinutes % 60
            let timeStr = hours > 0
                ? String(localized: "\(hours)시간 \(mins)분")
                : String(localized: "\(mins)분")
            summaryText = String(localized: "오늘 \(completedCount)건의 일정을 소화했으며, 총 \(timeStr)을 사용했습니다.")
        }

        let score = todayEvents.isEmpty ? 0.0 : Double(completedCount) / Double(todayEvents.count)

        dailySummary = DailySummary(
            date: log.date,
            summaryText: summaryText,
            highlights: log.highlights,
            nextActions: log.nextActions,
            detectedCategory: log.category,
            productivityScore: score,
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
        let isNew = dozyEventsByID[event.id] == nil
        let publisher = isNew
            ? createDozyEventUseCase.execute(event)
            : updateDozyEventUseCase.execute(event)
        publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                // 위젯에 즉시 시각 피드백 — loadTodayData 의 async fetch 체인 (Apple/Google
                // merge) 을 기다리지 않고 새로 만든 Dozy 일정을 캐시에 곧장 추가.
                TodayEventCacheWriter.upsertSingleDozyEvent(event, container: self.modelContainer)
                WidgetCenter.shared.reloadAllTimelines()
                // 이어서 full sync — Apple/Google 머지된 결과로 cache 재정렬.
                self.loadTodayData()
                if isNew { self.showSuccessAnimation = true }
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
        let id = dozyEvent.id
        deleteDozyEventUseCase.execute(dozyEvent)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                guard let self else { return }
                // 위젯 캐시에서 해당 id 즉시 제거 — UI 즉시 반영.
                TodayEventCacheWriter.removeSingleEvent(id: id, container: self.modelContainer)
                WidgetCenter.shared.reloadAllTimelines()
                self.loadTodayData()
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
            if let category {
                dozy.category = category
                if let ctx = dozy.modelContext,
                   let cat = try? ctx.fetch(FetchDescriptor<UserCategory>()).first(where: { $0.name == category }) {
                    dozy.colorHex = cat.colorHex
                }
            }
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
