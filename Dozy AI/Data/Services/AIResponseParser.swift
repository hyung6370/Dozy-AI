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
        
        // 각 섹션 추출 — AIPromptBuilder 와 동일한 영문 tag 사용 (한·영 공통).
        // 이전 한글 tag 응답과의 호환을 위해 alternate tag 도 함께 시도.
        let summaryText = extractSection(from: response, tags: ["Summary", "요약"])
            ?? String(response.prefix(200))

        let highlights = extractListSection(from: response, tags: ["Highlights", "하이라이트"])

        let nextActions = extractListSection(from: response, tags: ["Next Actions", "추천 할 일"])

        let category = extractSection(from: response, tags: ["Category", "카테고리"])
            .flatMap { normalizeCategory($0) }
            ?? detectCategoryFromEvents(events)

        let score = extractSection(from: response, tags: ["Score", "생산성 점수"])
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

    /// 여러 후보 tag 중 처음 매칭되는 섹션 반환. 영문 tag (현재) + 한글 tag (과거 호환) 같이 시도.
    private static func extractSection(from text: String, tags: [String]) -> String? {
        for tag in tags {
            if let result = extractSection(from: text, tag: tag) { return result }
        }
        return nil
    }

    /// [태그] 뒤의 텍스트를 정규식으로 추출
    private static func extractSection(from text: String, tag: String) -> String? {
        // 정규식 안전화 — tag 에 공백이 들어가는 영문 ("Next Actions") 도 안전.
        let escaped = NSRegularExpression.escapedPattern(for: tag)
        let patterns = [
            "\\[\(escaped)\\][:\\s]*\\n?([\\s\\S]*?)(?=\\n\\[|$)",
            "\(escaped)[:\\s]*\\n?([^\\[]*)"
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

    /// 여러 후보 tag 중 처음 매칭되는 리스트 섹션 반환.
    private static func extractListSection(from text: String, tags: [String]) -> [String] {
        for tag in tags {
            let list = extractListSection(from: text, tag: tag)
            if !list.isEmpty { return list }
        }
        return []
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

    /// AI 응답에서 추출한 카테고리를 그대로 반환 (사용자 정의 카테고리 지원)
    private static func normalizeCategory(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 이벤트의 기존 카테고리 중 가장 빈도 높은 것 반환
    private static func detectCategoryFromEvents(_ events: [CalendarEvent]) -> String {
        let nonDefault = events.map { $0.category }.filter { $0 != UserCategory.defaultName }
        guard !nonDefault.isEmpty else { return UserCategory.defaultName }
        let grouped = Dictionary(grouping: nonDefault) { $0 }
        return grouped.max(by: { $0.value.count < $1.value.count })?.key ?? UserCategory.defaultName
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
            let count = events.count
            highlights.append(String(localized: "오늘 \(count)건의 일정을 소화했습니다"))
        }
        if !tasks.isEmpty {
            let count = tasks.count
            highlights.append(String(localized: "\(count)개의 할 일을 완료했습니다"))
        }
        if let longest = events.filter({ !$0.isAllDay }).max(by: { $0.durationMinutes < $1.durationMinutes }) {
            let title = longest.title
            let dur = longest.durationMinutes
            highlights.append(String(localized: "'\(title)'에 \(dur)분을 사용했습니다"))
        }

        return highlights
    }
}
