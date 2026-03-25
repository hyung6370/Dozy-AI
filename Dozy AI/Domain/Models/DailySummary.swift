//
//  DailySummary.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation

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
        log.highlights = highlights
        log.nextActions = nextActions
        log.category = detectedCategory
        log.productivityScore = productivityScore
        log.updatedAt = Date()
    }
}
