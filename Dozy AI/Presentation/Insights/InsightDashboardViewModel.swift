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
        case .week: return "7일"
        case .month: return "30일"
        case .quarter: return "90일"
        }
    }
}

final class InsightDashboardViewModel: ObservableObject {
    
    @Published var insights: [InsightMessage] = []
    
    // MARK: - Period (B단계에서 UI 연결)
    @Published var selectedPeriod: InsightPeriod = .month
    
    // MARK: - 완료율 (DozyEvent 기반)
    @Published var averageCompletionRate: Double = 0
    @Published var completionRateChange: Double = 0
    @Published var dailyCompletionRates: [(date: Date, rate: Double)] = []
    @Published var currentStreak: Int = 0
    
    // MARK: - 패턴
    @Published var hourlyDistribution: [(hour: Int, count: Int)] = []
    @Published var peakHours: [Int] = []
    @Published var weekdayAvgCounts: [(weekday: Int, avg: Double)] = []
    @Published var recurringCount: Int = 0
    @Published var oneTimeCount: Int = 0
    
    // MARK: - WorkLog 기반
    @Published var categoryDistribution: [(category: String, count: Int)] = []
    @Published var productivityScores: [(date: Date, score: Double)] = []
    @Published var averageProductivityScore: Double? = nil
    
    // MARK: - 상태
    @Published var isLoading = false
    @Published var hasDozyData = false
    @Published var hasWorkLogData = false
    
    private let fetchEventsUseCase: FetchDozyEventsForPeriodUseCase
    private let fetchCompletionsUseCase: FetchEventCompletionsForPeriodUseCase
    private let fetchLogsUseCase: FetchRecentLogsUseCase
    private let patternService: PatternAnalysisService
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchEventsUseCase: FetchDozyEventsForPeriodUseCase,
        fetchCompletionsUseCase: FetchEventCompletionsForPeriodUseCase,
        fetchLogsUseCase: FetchRecentLogsUseCase,
        patternService: PatternAnalysisService
    ) {
        self.fetchEventsUseCase = fetchEventsUseCase
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
            Publishers.Zip3(
                fetchEventsUseCase.execute(from: start, to: now),
                fetchEventsUseCase.execute(from: prevStart, to: start),
                fetchLogsUseCase.execute(days: days)
            ),
            Publishers.Zip(
                fetchCompletionsUseCase.execute(from: start, to: now),
                fetchCompletionsUseCase.execute(from: prevStart, to: start)
            )
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] _ in self?.isLoading = false },
            receiveValue: { [weak self] eventsAndLogs, completions in
                guard let self else { return }
                let (current, previous, logs) = eventsAndLogs
                let (currentCal, previousCal) = completions
                self.isLoading = false
                self.applyEvents(current: current, previous: previous,
                                 currentCal: currentCal, previousCal: previousCal,
                                 days: days)
                self.applyLogs(logs, events: current, calendarCompletions: currentCal)
            }
        )
        .store(in: &cancellables)
    }

    private func applyEvents(current: [DozyEvent], previous: [DozyEvent], currentCal: [EventCompletion], previousCal: [EventCompletion], days: Int) {
        hasDozyData = !current.isEmpty || !currentCal.isEmpty
        averageCompletionRate = patternService.averageCompletionRate(from: current, calendarCompletions: currentCal)
        completionRateChange = patternService.completionRateChange(current: current, previous: previous, currentCal: currentCal, previousCal: previousCal)
        dailyCompletionRates = patternService.dailyCompletionRates(from: current, calendarCompletions: currentCal, days: min(days, 30))
        currentStreak = patternService.currentStreak(from: current, calendarCompletions: currentCal)
        hourlyDistribution = patternService.hourlyDistribution(from: current)
        peakHours = patternService.peakHours(from: current)
        weekdayAvgCounts = patternService.weekdayAverageCount(from: current, periodDays: days)
        
        let ratio = patternService.recurrenceRatio(from: current)
        recurringCount = ratio.recurring
        oneTimeCount = ratio.oneTime
    }
    
    private func applyLogs(_ logs: [WorkLog], events: [DozyEvent], calendarCompletions: [EventCompletion]) {
        hasWorkLogData = !logs.isEmpty
        categoryDistribution = patternService.categoryDistribution(from: logs)
        productivityScores = patternService.productivityScores(from: logs)
        averageProductivityScore = patternService.averageProductivityScore(from: logs)
        insights = patternService.generateInsights(events: events, calendarCompletions: calendarCompletions, logs: logs)
    }
}
