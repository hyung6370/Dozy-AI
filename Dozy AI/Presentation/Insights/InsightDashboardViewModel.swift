//
//  InsightDashboardViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/2/26.
//

import Foundation
import Combine

enum InsightPeriod: Int, CaseIterable {
    case week = 7
    case month = 30
    case quarter = 90

    var title: String {
        switch self {
        case .week: return String(localized: "7일")
        case .month: return String(localized: "30일")
        case .quarter: return String(localized: "90일")
        }
    }
}

@MainActor
final class InsightDashboardViewModel: ObservableObject {

    @Published var insights: [InsightMessage] = []

    // MARK: - Period
    @Published var selectedPeriod: InsightPeriod = .month

    // MARK: - 완료율 (DozyEvent + EventCompletion 기반)
    @Published var averageCompletionRate: Double = 0
    @Published var completionRateChange: Double = 0
    @Published var dailyCompletionRates: [(date: Date, rate: Double)] = []
    @Published var weeklyCompletionRates: [(date: Date, rate: Double)] = []
    @Published var currentStreak: Int = 0

    // MARK: - 패턴 (전체 캘린더 소스 기반)
    @Published var hourlyDistribution: [(hour: Int, count: Int)] = []
    @Published var peakHours: [Int] = []
    @Published var weekdayAvgCounts: [(weekday: Int, avg: Double)] = []
    @Published var recurringCount: Int = 0
    @Published var oneTimeCount: Int = 0

    // MARK: - WorkLog 기반
    @Published var categoryDistribution: [(category: String, count: Int)] = []
    @Published var productivityScores: [(date: Date, score: Double)] = []
    @Published var averageProductivityScore: Double? = nil

    // MARK: - 카테고리 분석용 raw 데이터
    @Published var periodCalendarEvents: [CalendarEvent] = []
    @Published var periodDozyEvents: [DozyEvent] = []

    // MARK: - 상태
    @Published var isLoading = false
    @Published var hasDozyData = false
    @Published var hasWorkLogData = false

    private let fetchEventsUseCase: FetchDozyEventsForPeriodUseCase
    private let fetchCalendarEventsUseCase: FetchCalendarEventsForPeriodUseCase
    private let fetchCompletionsUseCase: FetchEventCompletionsForPeriodUseCase
    private let fetchLogsUseCase: FetchRecentLogsUseCase
    private let patternService: PatternAnalysisService
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchEventsUseCase: FetchDozyEventsForPeriodUseCase,
        fetchCalendarEventsUseCase: FetchCalendarEventsForPeriodUseCase,
        fetchCompletionsUseCase: FetchEventCompletionsForPeriodUseCase,
        fetchLogsUseCase: FetchRecentLogsUseCase,
        patternService: PatternAnalysisService
    ) {
        self.fetchEventsUseCase = fetchEventsUseCase
        self.fetchCalendarEventsUseCase = fetchCalendarEventsUseCase
        self.fetchCompletionsUseCase = fetchCompletionsUseCase
        self.fetchLogsUseCase = fetchLogsUseCase
        self.patternService = patternService
    }

    func loadData() {
        isLoading = true
        let days = selectedPeriod.rawValue
        let cal = Calendar.current
        let now = Date()
        let start     = cal.date(byAdding: .day, value: -days, to: now)!
        let prevStart = cal.date(byAdding: .day, value: -days * 2, to: now)!

        Publishers.Zip(
            Publishers.Zip(
                Publishers.Zip3(
                    fetchEventsUseCase.execute(from: start, to: now),
                    fetchEventsUseCase.execute(from: prevStart, to: start),
                    fetchLogsUseCase.execute(days: days)
                ),
                Publishers.Zip(
                    fetchCompletionsUseCase.execute(from: start, to: now),
                    fetchCompletionsUseCase.execute(from: prevStart, to: start)
                )
            ),
            fetchCalendarEventsUseCase.execute(from: start, to: now)
                .replaceError(with: [])
                .setFailureType(to: DozyError.self)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] _ in self?.isLoading = false },
            receiveValue: { [weak self] dozyAndLogs, allCalendarEvents in
                guard let self else { return }
                let ((current, previous, logs), (currentCal, previousCal)) = dozyAndLogs
                self.isLoading = false
                self.applyEvents(
                    current: current, previous: previous,
                    currentCal: currentCal, previousCal: previousCal,
                    allCalendarEvents: allCalendarEvents,
                    days: days
                )
                self.applyLogs(logs, dozyEvents: current, allCalendarEvents: allCalendarEvents, calendarCompletions: currentCal, days: days)
            }
        )
        .store(in: &cancellables)
    }

    private func applyEvents(
        current: [DozyEvent],
        previous: [DozyEvent],
        currentCal: [EventCompletion],
        previousCal: [EventCompletion],
        allCalendarEvents: [CalendarEvent],
        days: Int
    ) {
        hasDozyData = !allCalendarEvents.isEmpty || !currentCal.isEmpty
        periodCalendarEvents = allCalendarEvents
        periodDozyEvents = current
        // 완료율 — 도지 + EventCompletion 기반
        averageCompletionRate = patternService.averageCompletionRate(from: current, calendarCompletions: currentCal)
        completionRateChange = patternService.completionRateChange(current: current, previous: previous, currentCal: currentCal, previousCal: previousCal)
        dailyCompletionRates = patternService.dailyCompletionRates(from: current, calendarCompletions: currentCal, days: days)
        weeklyCompletionRates = days > 30
            ? patternService.weeklyCompletionRates(from: current, calendarCompletions: currentCal, weeks: days / 7)
            : []
        currentStreak = patternService.currentStreak(from: current, calendarCompletions: currentCal)
        // 패턴 — 전체 캘린더 소스 기반
        hourlyDistribution = patternService.hourlyDistribution(from: allCalendarEvents)
        peakHours = patternService.peakHours(from: allCalendarEvents)
        weekdayAvgCounts = patternService.weekdayAverageCount(from: allCalendarEvents, periodDays: days)
        // 반복 비율 — 도지 이벤트 기반 (recurrenceRule 보유)
        let ratio = patternService.recurrenceRatio(from: current)
        recurringCount = ratio.recurring
        oneTimeCount = ratio.oneTime
    }

    private func applyLogs(
        _ logs: [WorkLog],
        dozyEvents: [DozyEvent],
        allCalendarEvents: [CalendarEvent],
        calendarCompletions: [EventCompletion],
        days: Int
    ) {
        hasWorkLogData = !logs.isEmpty
        categoryDistribution = patternService.categoryDistribution(from: logs)
        productivityScores = patternService.productivityScores(from: logs)
        averageProductivityScore = patternService.averageProductivityScore(from: logs)
        insights = patternService.generateInsights(
            allCalendarEvents: allCalendarEvents,
            dozyEvents: dozyEvents,
            calendarCompletions: calendarCompletions,
            logs: logs,
            periodDays: days
        )
    }
}
