//
//  DailySummaryViewModel.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine
import EventKit

final class DailySummaryViewModel: ObservableObject {
    
    // MARK: - 탭 상태
    @Published var selectedTab: SummaryTab = .overview
    
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
    
    // MARK: - Computed
    
    var hasEnoughData: Bool {
        !events.isEmpty || !completedTasks.isEmpty || !memos.isEmpty
    }
    
    var scorePercentage: Int {
        guard let score = summary?.productivityScore else { return 0 }
        return Int(score * 100)
    }
    
    /// 점수 구성 분석 (요약 탭에서 사용)
    var scoreBreakdown: [(label: String, value: Double, maxValue: Double)] {
        guard let summary else { return [] }
        
        let totalTasks = completedTasks.count + pendingTasks.count
        let completionRate = totalTasks > 0
        ? Double(completedTasks.count) / Double(totalTasks)
        : 0.5
        
        let eventRate = min(Double(events.count) / 5.0, 1.0)
        let volumeRate = min(Double(completedTasks.count) / 8.0, 1.0)
        
        return [
            ("할 일 완료율", completionRate * 50, 50),
            ("일정 소화", eventRate * 30, 30),
            ("완료 양", volumeRate * 20, 20)
        ]
    }
    
    /// 오늘의 가장 활발한 시간대
    var peakHourLabel: String {
        guard let peak = hourlyActivities.max(by: { $0.totalCount < $1.totalCount }) else {
            return "데이터 없음"
        }
        return peak.label
    }
    
    // MARK: - Dependencies
    private let aiService: AIServiceProtocol
    private let repository: WorkLogRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(aiService: AIServiceProtocol, repository: WorkLogRepositoryProtocol) {
        self.aiService = aiService
        self.repository = repository
    }
    
    convenience init(container: DependencyContainer) {
        self.init(
            aiService: container.aiService,
            repository: container.workLogRepository
        )
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
        
        aiService.generateDailySummary(
            events: events,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            memos: memos
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isGenerating = false
                self?.generationProgress = ""
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            },
            receiveValue: { [weak self] summary in
                guard let self else { return }
                self.summary = summary
                self.saveSummaryToLog(summary)
                
                // 모든 탭 데이터 계산
                self.buildHighlightsData()
                self.buildRecommendationsData()
                self.buildTrendsData()
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - 하이라이트 데이터 구축
    // 이벤트와 할일을 카테고리별로 그룹핑하고,
    // 시간대별 활동 빈도를 계산하여 시각화할 수 있게 합니다.
    
    func buildHighlightsData() {
        // 1) 카테고리별 하이라이트 분류
        var categoryMap: [WorkCategory: (items: [String], minutes: Int)] = [:]
        
        for event in events {
            let cat = detectSingleCategory(from: event.title)
            var entry = categoryMap[cat] ?? (items: [], minutes: 0)
            entry.items.append(event.title)
            entry.minutes += event.isAllDay ? 0 : event.durationMinutes
            categoryMap[cat] = entry
        }
        
        for task in completedTasks {
            let cat = detectSingleCategory(from: task.title)
            var entry = categoryMap[cat] ?? (items: [], minutes: 0)
            entry.items.append("✅ \(task.title)")
            categoryMap[cat] = entry
        }
        
        categorizedHighlights = categoryMap.map { cat, data in
            CategorizedHighlight(
                category: cat,
                items: data.items,
                totalMinutes: data.minutes
            )
        }
        .sorted { $0.items.count > $1.items.count }
        
        // 2) 시간대별 활동 분석
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
        
        // 업무 시간대만 표시 (7시~21시)
        hourlyActivities = (7...21).map { hour in
            let data = hourMap[hour] ?? (events: 0, tasks: 0)
            return HourlyActivity(
                hour: hour,
                eventCount: data.events,
                taskCount: data.tasks
            )
        }
    }
    
    // MARK: - 추천 할 일 데이터 구축
    // AI 추천 항목 + 미완료 항목을 우선순위별로 정렬하여
    // 사용자가 다음에 뭘 해야 할지 한눈에 파악할 수 있게 합니다.
    
    func buildRecommendationsData() {
        var actions: [RecommendedAction] = []
        
        // AI 추천 항목
        if let aiActions = summary?.nextActions {
            for action in aiActions {
                actions.append(RecommendedAction(
                    title: action.replacingOccurrences(of: "^[🔴⏰📋📌]\\s*", with: "", options: .regularExpression),
                    reason: "AI 추천",
                    priority: action.contains("🔴") ? .critical
                        : action.contains("⏰") ? .high
                        : .normal,
                    originalTask: nil,
                    isFromAI: true
                ))
            }
        }
        
        // 미완료 항목 중 우선순위 높은 것
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!.endOfDay
        
        for task in pendingTasks {
            // AI 추천과 중복 체크
            let isDuplicate = actions.contains { $0.title.contains(task.title) }
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
        
        // 우선순위순 정렬
        recommendedActions = actions.sorted { $0.priority < $1.priority }
    }
    
    // MARK: - 트렌드 데이터 구축
    // 최근 7일 WorkLog를 가져와 주간 추이 차트를 만듭니다.
    // 데이터가 없는 날은 0으로 채워 연속적인 차트가 되게 합니다.
    
    func buildTrendsData() {
        repository.fetchRecentLogs(days: 7)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] logs in
                    guard let self else { return }
                    self.processTrendData(logs: logs)
                }
            )
            .store(in: &cancellables)
    }
    
    private func processTrendData(logs: [WorkLog]) {
        // 7일 데이터 포인트 생성 (없는 날은 0)
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
                    date: date,
                    score: 0,
                    eventCount: 0,
                    taskCount: 0,
                    category: WorkCategory.general.rawValue
                ))
            }
        }
        
        weeklyTrend = points
        
        // 주간 평균 점수
        let validScores = points.filter { $0.score > 0 }
        weeklyAverageScore = validScores.isEmpty
            ? 0
            : validScores.reduce(0) { $0 + $1.score } / Double(validScores.count)
        
        // 카테고리 분포
        var catCounts: [WorkCategory: Int] = [:]
        for log in logs {
            let cat = WorkCategory(rawValue: log.category) ?? .general
            catCounts[cat, default: 0] += 1
        }
        
        let total = max(catCounts.values.reduce(0, +), 1)
        categoryDistribution = catCounts.map { cat, count in
            CategoryDistribution(
                category: cat,
                count: count,
                percentage: Double(count) / Double(total)
            )
        }
        .sorted { $0.count > $1.count }
    }
    
    // MARK: - 리마인더 추가
    // 추천 할 일을 바로 시스템 리마인더에 추가할 수 있어
    // 앱 밖에서도 알림을 받을 수 있습니다.
    
    func addToReminder(_ action: RecommendedAction) {
        let store = EKEventStore()
        
        store.requestFullAccessToReminders { [weak self] granted, _ in
            guard granted else { return }
            
            let reminder = EKReminder(eventStore: store)
            reminder.title = action.title
            reminder.calendar = store.defaultCalendarForNewReminders()
            
            // 마감일 설정: 내일
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: tomorrow
            )
            
            // 우선순위 매핑
            switch action.priority {
            case .critical: reminder.priority = 1
            case .high: reminder.priority = 5
            case .normal: reminder.priority = 9
            case .low: reminder.priority = 0
            }
            
            do {
                try store.save(reminder, commit: true)
                DispatchQueue.main.async {
                    self?.addedToReminder.insert(action.id)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "리마인더 추가에 실패했습니다."
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveSummaryToLog(_ summary: DailySummary) {
        repository.fetchLog(for: Date())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] existingLog in
                    guard let self, let log = existingLog else { return }
                    summary.apply(to: log)
                    self.repository.save(log)
                        .sink(receiveCompletion: { _ in }, receiveValue: { })
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
    }
    
    private func detectSingleCategory(from title: String) -> WorkCategory {
        let t = title.lowercased()
        if ["회의", "미팅", "meeting", "standup", "sync"].contains(where: { t.contains($0) }) { return .meeting }
        if ["리뷰", "review", "검토", "PR"].contains(where: { t.contains($0) }) { return .review }
        if ["개발", "코딩", "dev", "배포", "버그", "구현"].contains(where: { t.contains($0) }) { return .development }
        if ["기획", "플래닝", "설계"].contains(where: { t.contains($0) }) { return .planning }
        if ["문서", "doc", "작성", "정리"].contains(where: { t.contains($0) }) { return .documentation }
        return .general
    }
}
