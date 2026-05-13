//
//  DailySummary.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation

// MARK: - 탭 열거형
enum SummaryTab: String, CaseIterable {
    case daily  = "일별"
    case weekly = "주별"
}

// MARK: - 카테고리 정보 (UserCategory 뷰 독립 표현)
struct CategoryInfo {
    let name: String
    let emoji: String
    let colorHex: String
}

// MARK: - 하이라이트 카테고리 모델
struct CategorizedHighlight: Identifiable {
    let id = UUID()
    let category: CategoryInfo
    let items: [String]
    let totalMinutes: Int
}

// MARK: - 시간대 활동 모델
struct HourlyActivity: Identifiable {
    let id = UUID()
    let hour: Int
    let eventCount: Int
    let taskCount: Int
    
    var label: String {
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(period) \(displayHour)시"
    }
    
    var totalCount: Int { eventCount + taskCount }
}

// MARK: - 추천 할 일 모델 (우선순위 정렬용)
struct RecommendedAction: Identifiable {
    let id = UUID()
    let title: String
    let reason: String // "높은 순위", "마감 임박" 등
    let priority: ActionPriority
    let originalTask: TaskItem?
    let isFromAI: Bool
    
    enum ActionPriority: Int, Comparable {
        case critical = 0   // 빨강
        case high = 1       // 주황
        case normal = 2     // 파랑
        case low = 3        // 회색
        
        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - 주간 데이터 모델
struct DailyTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
    let eventCount: Int
    let taskCount: Int
    let category: String
    
    var weekdayLabel: String {
        date.weekdayString
    }
    
    var dateLabel: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

// MARK: - 카테고리 분포 모델
struct CategoryDistribution: Identifiable {
    let id = UUID()
    let category: CategoryInfo
    let count: Int
    let percentage: Double
}

// MARK: - DailSummary
struct DailySummary: Codable, Equatable {
    let date: Date
    let summaryText: String           // AI가 생성한 요약 본문
    let highlights: [String]          // 핵심 하이라이트 (3~5개)
    let nextActions: [String]         // 추천 다음 할 일 (3개)
    let detectedCategory: String      // 자동 감지된 주요 업무 카테고리
    let productivityScore: Double     // 생산성 점수 (0.0 ~ 1.0)
    let totalEventMinutes: Int        // 오늘 일정 총 소요시간(분)
    let completedTaskCount: Int       // 완료한 할 일 수
    
    /// WorkLog에 결과를 한 번에 반영하는 편의 메서드
    func apply(to log: WorkLog) {
        log.aiSummary = summaryText
        log.highlights = deduplicated(highlights)
        log.nextActions = deduplicated(nextActions)
        log.category = detectedCategory
        log.productivityScore = productivityScore
        log.updatedAt = Date()
    }

    private func deduplicated(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.lowercased()).inserted }
    }
}

// MARK: - 카테고리별 시간/건수 통계 (오늘)
struct CategoryTimeStat: Identifiable {
    let id = UUID()
    let category: CategoryInfo
    let eventCount: Int
    let totalMinutes: Int
    let percentage: Double       // 전체 시간 대비 비중
    let countPercentage: Double  // 전체 건수 대비 비중
}

// MARK: - 카테고리별 시간대 패턴 (오늘)
struct CategoryHourStat: Identifiable {
    let id = UUID()
    let category: CategoryInfo
    let peakHour: Int

    var peakHourLabel: String {
        let period = peakHour < 12 ? "오전" : "오후"
        let h = peakHour == 0 ? 12 : (peakHour > 12 ? peakHour - 12 : peakHour)
        return "\(period) \(h)시"
    }
}
