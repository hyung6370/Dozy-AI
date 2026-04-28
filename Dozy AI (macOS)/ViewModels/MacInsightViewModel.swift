//
//  MacInsightViewModel.swift
//  Dozy AI (macOS)
//
//  M4.9 — 인사이트 대시보드 ViewModel. DozyEvent + EventCompletion + WorkLog 기반.
//  Apple Calendar 연동 이후엔 CompositeCalendarSerivce 의 머지된 [CalendarEvent] 를
//  hourly/weekday/peakHours 분석에 함께 사용. completionRate / streak / recurrence 처럼
//  DozyEvent 자체가 필요한 분석은 그대로 fetchEventsUseCase(DozyEvent) 결과를 쓴다.
//

import Foundation
import Combine

enum MacInsightPeriod: Int, CaseIterable {
    case week = 7
    case month = 30
    case quarter = 90

    var title: String {
        switch self {
        case .week: return "7일"
        case .month: return "30일"
        case .quarter: return "90일"
        }
    }

    var label: String {
        switch self {
        case .week: return "지난 7일"
        case .month: return "지난 30일"
        case .quarter: return "지난 90일"
        }
    }
}

@MainActor
final class MacInsightViewModel: ObservableObject {

    // MARK: - Period

    @Published var selectedPeriod: MacInsightPeriod = .month

    // MARK: - 완료율

    @Published var averageCompletionRate: Double = 0
    @Published var completionRateChange: Double = 0
    @Published var dailyCompletionRates: [(date: Date, rate: Double)] = []
    @Published var weeklyCompletionRates: [(date: Date, rate: Double)] = []
    @Published var currentStreak: Int = 0

    // MARK: - 패턴

    @Published var hourlyDistribution: [(hour: Int, count: Int)] = []
    @Published var peakHours: [Int] = []
    @Published var weekdayAvgCounts: [(weekday: Int, avg: Double)] = []
    @Published var recurringCount: Int = 0
    @Published var oneTimeCount: Int = 0

    // MARK: - WorkLog

    @Published var categoryDistribution: [(category: String, count: Int)] = []
    @Published var productivityScores: [(date: Date, score: Double)] = []
    @Published var averageProductivityScore: Double? = nil

    // MARK: - 상태

    @Published var isLoading = false
    @Published var hasDozyData = false
    @Published var hasWorkLogData = false

    // MARK: - Raw 데이터 (카테고리 분석 화면에 그대로 전달)

    @Published var allEvents: [CalendarEvent] = []
    @Published var currentDozyEvents: [DozyEvent] = []

    // MARK: - Deps

    private let fetchEventsUseCase: FetchDozyEventsForPeriodUseCase
    private let fetchCalendarEventsUseCase: FetchCalendarEventsForPeriodUseCase
    private let fetchCompletionsUseCase: FetchEventCompletionsForPeriodUseCase
    private let fetchLogsUseCase: FetchRecentLogsUseCase
    private let patternService: PatternAnalysisService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(container: DependencyContainer) {
        self.fetchEventsUseCase = container.fetchDozyEventsForPeriodUseCase
        self.fetchCalendarEventsUseCase = container.fetchCalendarEventsForPeriodUseCase
        self.fetchCompletionsUseCase = container.fetchEventCompletionsForPeriodUseCase
        self.fetchLogsUseCase = container.fetchRecentLogsUseCase
        self.patternService = container.patternAnalysisService

        // 무거운 sync (Supabase pull / 캘린더 소스 토글) 와 가벼운 변경 (일정 체크 토글) 모두 listen.
        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadData() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .dozyEventChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadData() }
            .store(in: &cancellables)
    }

    // MARK: - Load

    func loadData() {
        isLoading = true
        let days = selectedPeriod.rawValue
        let cal = Calendar.current
        let now = Date()
        let start     = cal.date(byAdding: .day, value: -days, to: now)!
        let prevStart = cal.date(byAdding: .day, value: -days * 2, to: now)!

        // Combine 의 Zip 은 최대 4-tuple 까지 — Zip 두 개를 다시 Zip 으로 묶어 5+ 결과를 받음.
        let dozyAndCalendar = Publishers.Zip3(
            fetchEventsUseCase.execute(from: start, to: now),
            fetchEventsUseCase.execute(from: prevStart, to: start),
            fetchCalendarEventsUseCase.execute(from: start, to: now)
        )
        let completionsAndLogs = Publishers.Zip3(
            fetchCompletionsUseCase.execute(from: start, to: now),
            fetchCompletionsUseCase.execute(from: prevStart, to: start),
            fetchLogsUseCase.execute(days: days)
        )

        Publishers.Zip(dozyAndCalendar, completionsAndLogs)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in self?.isLoading = false },
                receiveValue: { [weak self] dozyTriple, completionTriple in
                    guard let self else { return }
                    let (current, previous, allEvents) = dozyTriple
                    let (currentCal, previousCal, logs) = completionTriple
                    self.isLoading = false
                    self.applyEvents(
                        current: current,
                        previous: previous,
                        allEvents: allEvents,
                        currentCompletions: currentCal,
                        previousCompletions: previousCal,
                        days: days
                    )
                    self.applyLogs(logs)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Apply

    private func applyEvents(
        current: [DozyEvent],
        previous: [DozyEvent],
        allEvents: [CalendarEvent],
        currentCompletions: [EventCompletion],
        previousCompletions: [EventCompletion],
        days: Int
    ) {
        // 카테고리 분석 화면 진입 시 raw 데이터 그대로 전달하기 위해 보관.
        self.allEvents = allEvents
        self.currentDozyEvents = current

        // hourly/weekday/peakHours 패턴 분석엔 Composite 가 머지한 [CalendarEvent] 사용
        // (Apple/Google 이벤트 시간대까지 함께 분석). DozyEvent 가 비었더라도 외부 캘린더
        // 일정이 있으면 데이터 있는 걸로 간주.
        hasDozyData = !current.isEmpty || !currentCompletions.isEmpty || !allEvents.isEmpty

        averageCompletionRate = patternService.averageCompletionRate(
            from: current, calendarCompletions: currentCompletions
        )
        completionRateChange = patternService.completionRateChange(
            current: current, previous: previous,
            currentCal: currentCompletions, previousCal: previousCompletions
        )
        dailyCompletionRates = patternService.dailyCompletionRates(
            from: current, calendarCompletions: currentCompletions, days: days
        )
        weeklyCompletionRates = days > 30
            ? patternService.weeklyCompletionRates(
                from: current, calendarCompletions: currentCompletions, weeks: days / 7
            )
            : []
        currentStreak = patternService.currentStreak(
            from: current, calendarCompletions: currentCompletions
        )

        hourlyDistribution = patternService.hourlyDistribution(from: allEvents)
        peakHours = patternService.peakHours(from: allEvents)
        weekdayAvgCounts = patternService.weekdayAverageCount(from: allEvents, periodDays: days)

        let ratio = patternService.recurrenceRatio(from: current)
        recurringCount = ratio.recurring
        oneTimeCount = ratio.oneTime
    }

    private func applyLogs(_ logs: [WorkLog]) {
        hasWorkLogData = !logs.isEmpty
        categoryDistribution = patternService.categoryDistribution(from: logs)
        productivityScores = patternService.productivityScores(from: logs)
        averageProductivityScore = patternService.averageProductivityScore(from: logs)
    }
}
