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
    private let fetchLogsUseCase: FetchRecentLogsUseCase
    private let patternService: PatternAnalysisService
    private var cancellables = Set<AnyCancellable>()
    
    init(
        fetchEventsUseCase: FetchDozyEventsForPeriodUseCase,
        fetchLogsUseCase: FetchRecentLogsUseCase,
        patternService: PatternAnalysisService
    ) {
        self.fetchEventsUseCase = fetchEventsUseCase
        self.fetchLogsUseCase = fetchLogsUseCase
        self.patternService = patternService
    }
    
    func loadData() {
        isLoading = true
        let days = selectedPeriod.rawValue
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -days, to: now)!
        let prevStart = cal.date(byAdding: .day, value: -days * 2, to: now)!
        
        Publishers.Zip3(
            fetchEventsUseCase.execute(from: start, to: now),
            fetchEventsUseCase.execute(from: prevStart, to: start),
            fetchLogsUseCase.execute(days: days)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] _ in self?.isLoading = false },
            receiveValue: { [weak self] current, previous, logs in
                guard let self else { return }
                self.isLoading = false
                self.applyEvents(current: current, previous: previous, days: days)
                self.applyLogs(logs)
            }
        )
        .store(in: &cancellables)
    }
    
    private func applyEvents(current: [DozyEvent], previous: [DozyEvent], days: Int) {
        hasDozyData = !current.isEmpty
        averageCompletionRate = patternService.averageCompletionRate(from: current)
        completionRateChange = patternService.completionRateChange(current: current, previous: previous)
        dailyCompletionRates = patternService.dailyCompletionRates(from: current, days: min(days, 30))
        currentStreak = patternService.currentStreak(from: current)
        hourlyDistribution = patternService.hourlyDistribution(from: current)
        peakHours = patternService.peakHours(from: current)
        weekdayAvgCounts = patternService.weekdayAverageCount(from: current, periodDays: days)
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
