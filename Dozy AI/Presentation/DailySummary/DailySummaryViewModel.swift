//
//  DailySummaryViewModel.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - MVVM]
//  ViewModel은 UseCase만 사용합니다.
//  Service나 Repository를 직접 참조하지 않습니다.

import Foundation
import Combine
import EventKit

final class DailySummaryViewModel: ObservableObject {

    // MARK: - 탭 상태

    @Published var selectedTab: SummaryTab = .daily

    // MARK: - 기본 상태

    @Published var summary: DailySummary?
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var generationProgress: String = ""

    // MARK: - 입력 데이터

    @Published var events: [CalendarEvent] = []
    @Published var completedTasks: [TaskItem] = []
    @Published var pendingTasks: [TaskItem] = []
    @Published var memos: [String] = []
    var completedEventCount: Int = 0

    // MARK: - 하이라이트 탭 데이터

    @Published var categorizedHighlights: [CategorizedHighlight] = []
    @Published var hourlyActivities: [HourlyActivity] = []

    // MARK: - 추천 탭 데이터

    @Published var recommendedActions: [RecommendedAction] = []
    @Published var addedToReminder: Set<UUID> = []

    // MARK: - 트렌드 탭 데이터

    @Published var weeklyTrend: [DailyTrendPoint] = []
    @Published var categoryDistribution: [CategoryDistribution] = []
    @Published var weeklyAverageScore: Double = 0

    // MARK: - 카테고리 분석 탭 데이터
    @Published var categoryTimeStats: [CategoryTimeStat] = []
    @Published var categoryHourStats: [CategoryHourStat] = []

    // MARK: - Computed

    var hasEnoughData: Bool {
        !events.isEmpty || !completedTasks.isEmpty || !memos.isEmpty
    }

    var scorePercentage: Int {
        guard let score = summary?.productivityScore else { return 0 }
        return Int(score * 100)
    }

    var scoreBreakdown: [(label: String, value: Double, maxValue: Double)] {
        guard summary != nil else { return [] }
        let total = events.isEmpty ? 2.0 : Double(events.count)
        return [("일정 완료율", Double(completedEventCount), total)]
    }

    var peakHourLabel: String {
        guard let peak = hourlyActivities.max(by: { $0.totalCount < $1.totalCount }) else {
            return "데이터 없음"
        }
        return peak.label
    }

    // MARK: - 사용자 카테고리 (View에서 주입)
    var userCategories: [UserCategory] = []

    // MARK: - Dependencies (UseCases만)

    private let generateSummaryUseCase: GenerateDailySummaryUseCase
    private let fetchRecentLogsUseCase: FetchRecentLogsUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        generateSummaryUseCase: GenerateDailySummaryUseCase,
        fetchRecentLogsUseCase: FetchRecentLogsUseCase
    ) {
        self.generateSummaryUseCase = generateSummaryUseCase
        self.fetchRecentLogsUseCase = fetchRecentLogsUseCase
    }

    // MARK: - AI 요약 생성

    func generateSummary() {
        guard hasEnoughData else {
            errorMessage = "요약할 데이터가 부족합니다."
            return
        }

        isGenerating = true
        errorMessage = nil
        generationProgress = "데이터 분석 중..."

        generateSummaryUseCase.execute(
            events: events,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            memos: memos,
            completedEventCount: completedEventCount
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.generationProgress = ""
                self?.isGenerating = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            },
            receiveValue: { [weak self] summary in
                guard let self else { return }
                self.summary = summary
                self.buildHighlightsData()
                self.buildRecommendationsData()
                self.buildTrendsData()
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - 하이라이트 데이터 구축

    func buildHighlightsData() {
        var categoryMap: [String: (info: CategoryInfo, items: [String], minutes: Int)] = [:]

        func infoFor(_ name: String) -> CategoryInfo {
            if let cat = userCategories.first(where: { $0.name == name }) {
                return CategoryInfo(name: cat.name, emoji: cat.emoji, colorHex: cat.colorHex)
            }
            return CategoryInfo(name: name, emoji: "📌", colorHex: "#8E8E93")
        }

        for event in events {
            let name = event.category
            var entry = categoryMap[name] ?? (info: infoFor(name), items: [], minutes: 0)
            entry.items.append(event.title)
            entry.minutes += event.isAllDay ? 0 : event.durationMinutes
            categoryMap[name] = entry
        }

        for task in completedTasks {
            let name = UserCategory.defaultName
            var entry = categoryMap[name] ?? (info: infoFor(name), items: [], minutes: 0)
            entry.items.append("✅ \(task.title)")
            categoryMap[name] = entry
        }

        categorizedHighlights = categoryMap.map { _, data in
            CategorizedHighlight(category: data.info, items: data.items, totalMinutes: data.minutes)
        }
        .sorted { $0.items.count > $1.items.count }

        var hourMap: [Int: (events: Int, tasks: Int)] = [:]

        for event in events where !event.isAllDay {
            let hour = Calendar.current.component(.hour, from: event.startDate)
            var entry = hourMap[hour] ?? (events: 0, tasks: 0)
            entry.events += 1
            hourMap[hour] = entry
        }

        for task in completedTasks {
            if let completed = task.completedDate {
                let hour = Calendar.current.component(.hour, from: completed)
                var entry = hourMap[hour] ?? (events: 0, tasks: 0)
                entry.tasks += 1
                hourMap[hour] = entry
            }
        }

        hourlyActivities = (7...21).map { hour in
            let data = hourMap[hour] ?? (events: 0, tasks: 0)
            return HourlyActivity(hour: hour, eventCount: data.events, taskCount: data.tasks)
        }
        buildCategoryAnalysis()
    }

    // MARK: - 추천 할 일 데이터 구축

    func buildRecommendationsData() {
        var actions: [RecommendedAction] = []
        var seenTitles = Set<String>()

        if let aiActions = summary?.nextActions {
            for action in aiActions {
                let cleanTitle = action.replacingOccurrences(of: "^[🔴⏰📋📌]\\s*", with: "", options: .regularExpression)
                let key = cleanTitle.lowercased()
                if seenTitles.contains(key) { continue }
                seenTitles.insert(key)
                actions.append(RecommendedAction(
                    title: cleanTitle,
                    reason: "Dozy 추천",
                    priority: action.contains("🔴") ? .critical
                        : action.contains("⏰") ? .high
                        : .normal,
                    originalTask: nil,
                    isFromAI: true
                ))
            }
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!.endOfDay

        for task in pendingTasks {
            let taskKey = task.title.lowercased()
            let isDuplicate = actions.contains {
                $0.title.lowercased().contains(taskKey) || taskKey.contains($0.title.lowercased())
            }
            if isDuplicate { continue }

            let isOverdue = task.dueDate.map { $0 < Date() } ?? false
            let isDueSoon = task.dueDate.map { $0 <= tomorrow } ?? false

            let priority: RecommendedAction.ActionPriority
            let reason: String

            if task.priority == 1 || isOverdue {
                priority = .critical
                reason = isOverdue ? "마감일 초과" : "높은 우선순위"
            } else if isDueSoon {
                priority = .high
                reason = "마감 임박 (\(task.dueDate?.formattedKorean ?? ""))"
            } else if task.priority == 5 {
                priority = .normal
                reason = "중간 우선순위"
            } else {
                priority = .low
                reason = task.listName.isEmpty ? "일반" : task.listName
            }

            actions.append(RecommendedAction(
                title: task.title,
                reason: reason,
                priority: priority,
                originalTask: task,
                isFromAI: false
            ))
        }

        recommendedActions = actions.sorted { $0.priority < $1.priority }
    }

    // MARK: - 트렌드 데이터 구축

    func buildTrendsData() {
        fetchRecentLogsUseCase.execute(days: 7)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] logs in
                    self?.processTrendData(logs: logs)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 추천 액션 삭제

    func removeAction(_ action: RecommendedAction) {
        recommendedActions.removeAll { $0.id == action.id }
    }

    // MARK: - 리마인더 추가
    // NOTE: 이 메서드는 직접 EKEventStore를 사용합니다.
    // 추후 ReminderServiceProtocol에 addReminder 메서드를 추가하고
    // UseCase로 분리하는 것을 권장합니다.

    func addToReminder(_ action: RecommendedAction) {
        let store = EKEventStore()

        store.requestFullAccessToReminders { [weak self] granted, _ in
            guard granted else { return }

            let reminder = EKReminder(eventStore: store)
            reminder.title = action.title
            reminder.calendar = store.defaultCalendarForNewReminders()

            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day], from: tomorrow
            )

            switch action.priority {
            case .critical: reminder.priority = 1
            case .high:     reminder.priority = 5
            case .normal:   reminder.priority = 9
            case .low:      reminder.priority = 0
            }

            do {
                try store.save(reminder, commit: true)
                DispatchQueue.main.async { self?.addedToReminder.insert(action.id) }
            } catch {
                DispatchQueue.main.async { self?.errorMessage = "리마인더 추가에 실패했습니다." }
            }
        }
    }

    // MARK: - Private Helpers

    private func processTrendData(logs: [WorkLog]) {
        var points: [DailyTrendPoint] = []

        for daysAgo in (0..<7).reversed() {
            let date = Date().daysAgo(daysAgo).startOfDay

            if let log = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                points.append(DailyTrendPoint(
                    date: date,
                    score: log.productivityScore ?? 0,
                    eventCount: log.rawEventTitles.count,
                    taskCount: log.completedTaskTitles.count,
                    category: log.category
                ))
            } else {
                points.append(DailyTrendPoint(
                    date: date, score: 0, eventCount: 0, taskCount: 0,
                    category: UserCategory.defaultName
                ))
            }
        }

        weeklyTrend = points

        let validScores = points.filter { $0.score > 0 }
        weeklyAverageScore = validScores.isEmpty
            ? 0
            : validScores.reduce(0) { $0 + $1.score } / Double(validScores.count)

        var catCounts: [String: Int] = [:]
        for log in logs {
            catCounts[log.category, default: 0] += 1
        }

        let total = max(catCounts.values.reduce(0, +), 1)
        categoryDistribution = catCounts.map { name, count in
            let info: CategoryInfo
            if let cat = userCategories.first(where: { $0.name == name }) {
                info = CategoryInfo(name: cat.name, emoji: cat.emoji, colorHex: cat.colorHex)
            } else {
                info = CategoryInfo(name: name, emoji: "📌", colorHex: "#8E8E93")
            }
            return CategoryDistribution(category: info, count: count, percentage: Double(count) / Double(total))
        }
        .sorted { $0.count > $1.count }
    }

    // MARK: - 카테고리 분석 데이터 구축
    func buildCategoryAnalysis() {
        var timeMap: [String: (info: CategoryInfo, count: Int, minutes: Int)] = [:]
        var hourMap: [String: [Int: Int]] = [:]

        func infoFor(_ name: String) -> CategoryInfo {
            if let cat = userCategories.first(where: { $0.name == name }) {
                return CategoryInfo(name: cat.name, emoji: cat.emoji, colorHex: cat.colorHex)
            }
            return CategoryInfo(name: name, emoji: "📌", colorHex: "#8E8E93")
        }

        for event in events {
            let name = event.category
            var entry = timeMap[name] ?? (info: infoFor(name), count: 0, minutes: 0)
            entry.count += 1
            entry.minutes += event.isAllDay ? 0 : event.durationMinutes
            timeMap[name] = entry

            if !event.isAllDay {
                let hour = Calendar.current.component(.hour, from: event.startDate)
                var hours = hourMap[name] ?? [:]
                hours[hour, default: 0] += 1
                hourMap[name] = hours
            }
        }

        let totalMinutes = max(timeMap.values.reduce(0) { $0 + $1.minutes }, 1)
        let totalCount   = max(timeMap.values.reduce(0) { $0 + $1.count  }, 1)

        categoryTimeStats = timeMap.map { name, data in
            CategoryTimeStat(
                category: data.info,
                eventCount: data.count,
                totalMinutes: data.minutes,
                percentage: Double(data.minutes) / Double(totalMinutes),
                countPercentage: Double(data.count) / Double(totalCount)
            )
        }
        .sorted { $0.totalMinutes != $1.totalMinutes
            ? $0.totalMinutes > $1.totalMinutes
            : $0.eventCount   > $1.eventCount }

        categoryHourStats = hourMap.compactMap { name, hours in
            guard !hours.isEmpty else { return nil }
            let peakHour = hours.max(by: { $0.value < $1.value })?.key ?? 9
            return CategoryHourStat(category: infoFor(name), peakHour: peakHour)
        }
        .sorted { $0.category.name < $1.category.name }
    }

}
