//
//  MacInsightViewModel.swift
//  Dozy AI (macOS)
//
//  M4.9 — 인사이트 대시보드 ViewModel. DozyEvent + EventCompletion + WorkLog 기반.
//  iOS 는 네이티브 캘린더 이벤트(Apple/Google/Naver)까지 함께 분석하지만
//  macOS 는 Supabase DozyEvent 만 취급하므로 패턴 분석 입력도 DozyEvent → CalendarEvent
//  변환본 하나만 사용한다.
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

    // MARK: - Deps

    private let fetchEventsUseCase: FetchDozyEventsForPeriodUseCase
    private let fetchCompletionsUseCase: FetchEventCompletionsForPeriodUseCase
    private let fetchLogsUseCase: FetchRecentLogsUseCase
    private let patternService: PatternAnalysisService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(container: DependencyContainer) {
        self.fetchEventsUseCase = container.fetchDozyEventsForPeriodUseCase
        self.fetchCompletionsUseCase = container.fetchEventCompletionsForPeriodUseCase
        self.fetchLogsUseCase = container.fetchRecentLogsUseCase
        self.patternService = container.patternAnalysisService
    }

    // MARK: - Load

    func loadData() {
        isLoading = true
        let days = selectedPeriod.rawValue
        let cal = Calendar.current
        let now = Date()
        let start     = cal.date(byAdding: .day, value: -days, to: now)!
        let prevStart = cal.date(byAdding: .day, value: -days * 2, to: now)!

        Publishers.Zip3(
            Publishers.Zip(
                fetchEventsUseCase.execute(from: start, to: now),
                fetchEventsUseCase.execute(from: prevStart, to: start)
            ),
            Publishers.Zip(
                fetchCompletionsUseCase.execute(from: start, to: now),
                fetchCompletionsUseCase.execute(from: prevStart, to: start)
            ),
            fetchLogsUseCase.execute(days: days)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] _ in self?.isLoading = false },
            receiveValue: { [weak self] dozyPair, completionPair, logs in
                guard let self else { return }
                let (current, previous) = dozyPair
                let (currentCal, previousCal) = completionPair
                self.isLoading = false
                self.applyEvents(
                    current: current,
                    previous: previous,
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
        currentCompletions: [EventCompletion],
        previousCompletions: [EventCompletion],
        days: Int
    ) {
        // macOS 는 네이티브 캘린더 이벤트가 없어서 DozyEvent 의 CalendarEvent 변환본을
        // allCalendarEvents 자리에 그대로 사용.
        let allEvents = current.map { $0.toCalendarEvent() }
        hasDozyData = !current.isEmpty || !currentCompletions.isEmpty

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
