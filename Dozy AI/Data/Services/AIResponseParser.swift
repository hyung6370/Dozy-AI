//
//  AIResponseParser.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//

import Foundation

enum AIResponseParser {
    
    /// AI 응답 텍스트 → DailySummary 변환
    static func parse(
        response: String,
        date: Date,
        events: [CalendarEvent],
        completedTasks: [TaskItem]
    ) -> DailySummary {
        
        // 각 섹션 추출 (실패 시 폴백)
        let summaryText = extractSection(from: response, tag: "요약")
            ?? String(response.prefix(200))
        
        let highlights = extractListSection(from: response, tag: "하이라이트")
        
        let nextActions = extractListSection(from: response, tag: "추천 할 일")
        
        let category = extractSection(from: response, tag: "카테고리")
            .flatMap { normalizeCategory($0) }
            ?? detectCategoryFromEvents(events)
        
        let score = extractSection(from: response, tag: "생산성 점수")
            .flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            ?? calculateFallbackScore(events: events, completedTasks: completedTasks)
        
        let totalMinutes = events
            .filter { !$0.isAllDay }
            .reduce(0) { $0 + $1.durationMinutes }
        
        return DailySummary(
            date: date,
            summaryText: summaryText,
            highlights: highlights.isEmpty
                ? generateFallbackHighlights(events: events, tasks: completedTasks)
                : highlights,
            nextActions: nextActions,
            detectedCategory: category,
            productivityScore: min(max(score, 0.0), 1.0),
            totalEventMinutes: totalMinutes,
            completedTaskCount: completedTasks.count
        )
    }
    
    // MARK: - 섹션 추출
    
    /// [태그] 뒤의 텍스트를 정규식으로 추출
    private static func extractSection(from text: String, tag: String) -> String? {
        let patterns = [
            "\\[\(tag)\\][:\\s]*\\n?([\\s\\S]*?)(?=\\n\\[|$)",
            "\(tag)[:\\s]*\\n?([^\\[]*)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
               ),
               let range = Range(match.range(at: 1), in: text) {
                
                let extracted = String(text[range])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !extracted.isEmpty { return extracted }
            }
        }
        return nil
    }
    
    /// [태그] 뒤의 "- " 리스트 항목들을 추출
    private static func extractListSection(from text: String, tag: String) -> [String] {
        guard let section = extractSection(from: text, tag: tag) else { return [] }
        
        var seen = Set<String>()
        return section
            .components(separatedBy: .newlines)
            .map { line in
                line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
            }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }
    
    // MARK: - 카테고리 정규화
    
    private static func normalizeCategory(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let mapping: [String: WorkCategory] = [
            "개발": .development, "코딩": .development, "프로그래밍": .development,
            "회의": .meeting, "미팅": .meeting,
            "리뷰": .review, "코드리뷰": .review, "검토": .review,
            "기획": .planning, "플래닝": .planning,
            "문서": .documentation, "문서화": .documentation, "작성": .documentation,
            "일반": .general
        ]
        
        for (keyword, category) in mapping {
            if trimmed.contains(keyword) { return category.rawValue }
        }
        return WorkCategory.general.rawValue
    }
    
    /// 이벤트 제목에서 카테고리 감지
    private static func detectCategoryFromEvents(_ events: [CalendarEvent]) -> String {
        let allTitles = events.map { $0.title.lowercased() }.joined(separator: " ")
        
        let keywords: [(WorkCategory, [String])] = [
            (.meeting, ["회의", "미팅", "meeting", "standup", "sync", "1:1"]),
            (.review, ["리뷰", "review", "검토", "PR"]),
            (.development, ["개발", "코딩", "dev", "sprint", "배포", "deploy"]),
            (.planning, ["기획", "플래닝", "planning", "브레인스토밍"]),
            (.documentation, ["문서", "doc", "작성", "wiki", "정리"])
        ]
        
        var scores: [WorkCategory: Int] = [:]
        for (category, words) in keywords {
            scores[category] = words.reduce(0) { $0 + (allTitles.contains($1) ? 1 : 0) }
        }
        
        if let top = scores.max(by: { $0.value < $1.value }), top.value > 0 {
            return top.key.rawValue
        }
        return WorkCategory.general.rawValue
    }
    
    // MARK: - 폴백 계산
    
    private static func calculateFallbackScore(
        events: [CalendarEvent],
        completedTasks: [TaskItem]
    ) -> Double {
        let total = completedTasks.count
        guard total > 0 else { return 0.5 }
        return min(Double(total) / 8.0, 1.0)
    }
    
    private static func generateFallbackHighlights(
        events: [CalendarEvent],
        tasks: [TaskItem]
    ) -> [String] {
        var highlights: [String] = []
        
        if !events.isEmpty {
            highlights.append("오늘 \(events.count)건의 일정을 소화했습니다")
        }
        if !tasks.isEmpty {
            highlights.append("\(tasks.count)개의 할 일을 완료했습니다")
        }
        if let longest = events.filter({ !$0.isAllDay }).max(by: { $0.durationMinutes < $1.durationMinutes }) {
            highlights.append("'\(longest.title)'에 \(longest.durationMinutes)분을 사용했습니다")
        }
        
        return highlights
    }
}
