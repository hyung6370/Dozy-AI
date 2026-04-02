//
//  PatternAnalysisService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation

final class PatternAnalysisService {
    
    // 최근 N일 WorkLog로 주간 생산성 추이 계산
    func weeklyProductivity(from logs: [WorkLog]) -> [(date: Date, score: Double)] {
        logs.suffix(7).compactMap { log in
            guard let score = log.productivityScore else { return nil }
            return (date: log.date, score: score)
        }
    }
    
    // 카테고리 분포 (빈도 기준)
    func categoryDistribution(from logs: [WorkLog]) -> [(category: String, count: Int)] {
        var freq: [String: Int] = [:]
        for log in logs where !log.category.isEmpty {
            freq[log.category, default: 0] += 1
        }
        return freq.map { ($0.key, $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    // 요일별 평균 생산성 (0=일 ~ 6=토)
    func weekdayAverageScore(from logs: [WorkLog]) -> [(weekday: Int, score: Double)] {
        var totals: [Int: (sum: Double, count: Int)] = [:]
        let cal = Calendar.current
        for log in logs {
            guard let score = log.productivityScore else { continue }
            let wd = cal.component(.weekday, from: log.date) - 1 // 0-based
            totals[wd, default: (0, 0)].sum += score
            totals[wd, default: (0, 0)].count += 1
        }
        return (0..<7).compactMap { wd in
            guard let t = totals[wd], t.count > 0 else { return nil }
            return (weekday: wd, score: t.sum / Double(t.count))
        }
    }
    
    // 평균 생산성 점수
    func averageScore(from logs: [WorkLog]) -> Double {
        let valid = logs.compactMap(\.productivityScore)
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }
}
