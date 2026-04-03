//
//  PatternAnalysisService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation

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
}
