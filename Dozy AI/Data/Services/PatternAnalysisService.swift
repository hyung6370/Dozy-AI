//
//  PatternAnalysisService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import SwiftUI

struct InsightMessage: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let text: String
}

final class PatternAnalysisService {
    
    // MARK: - 완료율

    func averageCompletionRate(from events: [DozyEvent],
                               calendarCompletions: [EventCompletion] = []) -> Double {
        let dozyTotal = events.count
        let calTotal  = calendarCompletions.count
        let total = dozyTotal + calTotal
        guard total > 0 else { return 0 }

        let dozyCompleted = events.filter(\.isCompleted).count
        let calCompleted  = calendarCompletions.filter(\.isCompleted).count
        return Double(dozyCompleted + calCompleted) / Double(total)
    }

    /// 일별 완료율 트렌드 (DozyEvent + CalendarEvent completions 합산)
    func dailyCompletionRates(from events: [DozyEvent],
                              calendarCompletions: [EventCompletion] = [],
                              days: Int) -> [(date: Date, rate: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        return (0..<days).reversed().compactMap { offset -> (Date, Double)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { return nil }

            let dayDozy = events.filter {
                let s = cal.startOfDay(for: $0.startDate)
                return s >= day && s < nextDay
            }
            let dayCal = calendarCompletions.filter {
                let s = cal.startOfDay(for: $0.eventDate)
                return s >= day && s < nextDay
            }

            let total = dayDozy.count + dayCal.count
            guard total > 0 else { return nil }

            let completed = dayDozy.filter(\.isCompleted).count
                          + dayCal.filter(\.isCompleted).count
            return (day, Double(completed) / Double(total))
        }
    }

    // MARK: - 이전 기간 대비 변화

    /// 양수: 개선, 음수: 감소 (0.15 = +15%)
    func completionRateChange(current: [DozyEvent], previous: [DozyEvent],
                              currentCal: [EventCompletion] = [],
                              previousCal: [EventCompletion] = []) -> Double {
        let cur  = averageCompletionRate(from: current,  calendarCompletions: currentCal)
        let prev = averageCompletionRate(from: previous, calendarCompletions: previousCal)
        guard prev > 0 else { return cur > 0 ? 1.0 : 0 }
        return (cur - prev) / prev
    }
    
    // MARK: - 연속 달성 스트릭
    
    func currentStreak(from events: [DozyEvent],
                       calendarCompletions: [EventCompletion] = [],
                       threshold: Double = 0.5) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var streak = 0
        var offset = 0

        while true {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { break }

            let dayDozy = events.filter {
                let s = cal.startOfDay(for: $0.startDate)
                return s >= day && s < nextDay
            }
            let dayCal = calendarCompletions.filter {
                let s = cal.startOfDay(for: $0.eventDate)
                return s >= day && s < nextDay
            }

            let total = dayDozy.count + dayCal.count
            if total == 0 {
                if offset == 0 { offset += 1; continue }
                else { break }
            }

            let completed = dayDozy.filter(\.isCompleted).count
                          + dayCal.filter(\.isCompleted).count
            let rate = Double(completed) / Double(total)
            if rate >= threshold {
                streak += 1
                offset += 1
            } else {
                break
            }
        }
        return streak
    }
    
    // MARK: - 시간대별 집중도
    
    func hourlyDistribution(from events: [DozyEvent]) -> [(hour: Int, count: Int)] {
        var counts: [Int: Int] = [:]
        for event in events where !event.isAllDay {
            let hour = Calendar.current.component(.hour, from: event.startDate)
            counts[hour, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.hour < $1.hour }
    }
    
    func peakHours(from events: [DozyEvent]) -> [Int] {
        hourlyDistribution(from: events)
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map(\.hour)
    }
    
    // MARK: - 반복 vs 단발성
    
    func recurrenceRatio(from events: [DozyEvent]) -> (recurring: Int, oneTime: Int) {
        let recurring = events.filter { $0.recurrenceRule != "none" }.count
        return (recurring, events.count - recurring)
    }
    
    // MARK: - 요일별 평균 일정 수
    
    func weekdayAverageCount(from events: [DozyEvent], periodDays: Int) -> [(weekday: Int, avg: Double)] {
        let cal = Calendar.current
        var totals: [Int: Int] = [:]
        for event in events {
            let wd = cal.component(.weekday, from: event.startDate) - 1
            totals[wd, default: 0] += 1
        }
        let numWeeks = max(1, periodDays / 7)
        return (0..<7).map { wd in
            (weekday: wd, avg: Double(totals[wd, default: 0]) / Double(numWeeks))
        }
    }
    
    // MARK: - WorkLog 기반
    
    func categoryDistribution(from logs: [WorkLog]) -> [(category: String, count: Int)] {
        var freq: [String: Int] = [:]
        for log in logs where !log.category.isEmpty && log.category != "일반" {
            freq[log.category, default: 0] += 1
        }
        return freq.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }
    
    func productivityScores(from logs: [WorkLog]) -> [(date: Date, score: Double)] {
        logs.compactMap { log in
            guard let score = log.productivityScore else { return nil }
            return (date: log.date, score: score)
        }
        .sorted { $0.date < $1.date }
    }
    
    func averageProductivityScore(from logs: [WorkLog]) -> Double? {
        let valid = logs.compactMap(\.productivityScore)
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / Double(valid.count)
    }
    
    // MARK: - AI 인사이트 문구 생성
    func generateInsights(events: [DozyEvent], calendarCompletions: [EventCompletion] = [], logs: [WorkLog]) -> [InsightMessage] {
        
        var insights: [InsightMessage] = []
        
        // 1. 완료율 평가
        let rate = averageCompletionRate(from: events, calendarCompletions: calendarCompletions)
        if rate >= 0.8 {
            insights.append(.init(icon: "star.fill", color: .yellow, text: "일정 완료율이 \(Int(rate * 100))% 에요. 훌륭한 집중력이에요!"))
        } else if rate >= 0.5 {
            insights.append(.init(icon: "checkmark.circle", color: .green, text: "일정의 절반 이상을 완료하고 있어요. 조금만 더 힘내봐요!"))
        } else if rate > 0 {
            insights.append(.init(icon: "exclamationmark.circle", color: .orange, text: "완료율이 \(Int(rate * 100))%예요. 일정을 줄이거나 우선순위를 조정해보세요."))
        }
        
        // 2. 피크 시간대
        let peaks = peakHours(from: events)
        if let top = peaks.first {
            let period = top < 12 ? "오전" : top < 18 ? "오후" : "저녁"
            insights.append(.init(icon: "clock.fill", color: .blue, text: "\(period) \(top % 12 == 0 ? 12 : top % 12)시가 가장 바쁜 시간대예요."))
        }
        
        // 3. 가장 바쁜 요일
        let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]
        let weekdayData = weekdayAverageCount(from: events, periodDays: 30)
        if let busiest = weekdayData.max(by: { $0.avg < $1.avg }), busiest.avg > 0 {
            insights.append(.init(icon: "calendar", color: .purple,
                                  text: "\(weekdayLabels[busiest.weekday])요일에 평균 \(String(format: "%.1f", busiest.avg))개로 가장 일정이 많아요."))
        }
        
        // 4. 연속 달성 스트릭
        let streak = currentStreak(from: events, calendarCompletions: calendarCompletions)
        if streak >= 7 {
            insights.append(.init(icon: "flame.fill", color: .orange, text: "\(streak)일 연속 목표를 달성하고 있어요. 대단해요!"))
        } else if streak >= 3 {
            insights.append(.init(icon: "flame", color: .orange, text: "\(streak)일 연속 달성 중이에요. 기세를 이어가요!"))
        }
        
        // 5. 반복 일정 비율
        let ratio = recurrenceRatio(from: events)
        let total = ratio.recurring + ratio.oneTime
        if total > 0 {
            let recurringPct = Int(Double(ratio.recurring) / Double(total) * 100)
            if recurringPct >= 70 {
                insights.append(.init(icon: "arrow.trianglehead.clockwise", color: .teal, text: "일정의 \(recurringPct)% 가 반복 일정이에요. 루틴이 잘 잡혀 있어요."))
            }
        }
        
        // 6. 생산성 점수 트렌드 (WorkLog 기반)
        let scores = productivityScores(from: logs)
        if scores.count >= 2 {
            let recent = scores.suffix(3).map(\.score).reduce(0, +) / Double(min(scores.count, 3))
            let older  = scores.prefix(max(1, scores.count - 3)).map(\.score).reduce(0, +) / Double(max(1, scores.count - 3))
            if recent > older + 0.1 {
                insights.append(.init(icon: "arrow.up.right.circle.fill", color: .green,
                                      text: "최근 생산성 점수가 꾸준히 오르고 있어요!"))
            } else if recent < older - 0.1 {
                insights.append(.init(icon: "arrow.down.right.circle", color: .red,
                                      text: "최근 생산성이 다소 떨어졌어요. 휴식이 필요할 수도 있어요."))
            }
        }
        
        return insights
    }
}
