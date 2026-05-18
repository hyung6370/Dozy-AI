//
//  AIService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine
import NaturalLanguage

final class AIService: AIServiceProtocol {
    
    // MARK: - 일일 요약 생성
    
    func generateDailySummary(events: [CalendarEvent], completedTasks: [TaskItem], pendingTasks: [TaskItem], memos: [String], completedEventCount: Int = 0) async throws -> DailySummary {
        
        // Foundation Models 사용 가능 시 (iOS 26+)
        if #available(iOS 26.0, *), Self.isFoundationModelsAvailable() {
            let prompt = AIPromptBuilder.buildDailySummaryPrompt(
                events: events,
                completedTasks: completedTasks,
                pendingTasks: pendingTasks,
                memos: memos
            )
            let response = try await requestFoundationModels(prompt: prompt)
            
            return AIResponseParser.parse(
                response: response,
                date: Date(),
                events: events,
                completedTasks: completedTasks
            )
        }
        
        // 폴백: NaturalLanguage 기반 로컬 분석
        return generateWithLocalAnalysis(
            events: events,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            memos: memos,
            completedEventCount: completedEventCount
        )
    }
    
    // MARK: - 빠른 한줄 요약 (async)
    func generateQuickSummary(events: [CalendarEvent], completedTasks: [TaskItem]) async throws -> String {
        if #available(iOS 26.0, *), Self.isFoundationModelsAvailable() {
            let prompt = AIPromptBuilder.buildQuickSummaryPrompt(
                events: events,
                completedTasks: completedTasks
            )
            return try await requestFoundationModels(prompt: prompt)
        }
        
        return buildQuickSummaryLocally(events: events, completedTasks: completedTasks)
    }
    
    // MARK: - Foundation Models (iOS 26+)
    
    /// Foundation Models 사용 가능 여부 체크
    private static func isFoundationModelsAvailable() -> Bool {
        // Xcode 26+에서 FoundationModels.isAvailable 등으로 교체
        if #available(iOS 26.0, *) {
            return false  // Xcode 26 전까지 false
        }
        return false
    }
    
    /// Foundation Models 호출
    @available(iOS 26.0, *)
    private func requestFoundationModels(prompt: String) async throws -> String {
        // ──────────────────────────────────────────
        // Xcode 26+ 에서 아래 코드를 활성화:
        //
        // import FoundationModels
        // let session = LanguageModelSession()
        // let response = try await session.respond(to: prompt)
        // return response.content
        // ──────────────────────────────────────────
        throw DozyError.aiSummarizationFailed
    }
    
    // MARK: - NaturalLanguage 기반 로컬 분석
    // NLTagger 키워드 추출 + 규칙 기반 로직 조합
    private func generateWithLocalAnalysis(events: [CalendarEvent], completedTasks: [TaskItem], pendingTasks: [TaskItem], memos: [String], completedEventCount: Int = 0) -> DailySummary {
        let summaryText = buildLocalSummaryText(
            events: events,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            memos: memos,
            completedEventCount: completedEventCount
        )
        
        let highlights = extractLocalHighlights(
            events: events,
            completedTasks: completedTasks,
            memos: memos
        )
        
        let nextActions = recommendNextActions(
            pendingTasks: pendingTasks,
            events: events
        )
        
        let category = detectCategory(events: events, tasks: completedTasks)
        
        let score = calculateProductivityScore(
            events: events,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            completedEventCount: completedEventCount
        )
        
        let totalMinutes = events
            .filter { !$0.isAllDay }
            .reduce(0) { $0 + $1.durationMinutes }
        
        return DailySummary(
            date: Date(),
            summaryText: summaryText,
            highlights: highlights,
            nextActions: nextActions,
            detectedCategory: category,
            productivityScore: score,
            totalEventMinutes: totalMinutes,
            completedTaskCount: completedTasks.count
        )
    }
    
    // MARK: - 로컬 요약 텍스트 생성
    private func buildLocalSummaryText(events: [CalendarEvent], completedTasks: [TaskItem], pendingTasks: [TaskItem], memos: [String], completedEventCount: Int = 0) -> String {

        var parts: [String] = []

        if completedEventCount == 0 {
            parts.append(String(localized: "오늘은 아직 완료된 일정이 없습니다."))
        } else {
            let now = Date()
            let pastEvents = events.filter { $0.endDate <= now }
            let totalMinutes = pastEvents
                .filter { !$0.isAllDay }
                .reduce(0) { $0 + $1.durationMinutes }
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            let timeStr = hours > 0
                ? String(localized: "\(hours)시간 \(mins)분")
                : String(localized: "\(mins)분")

            parts.append(String(localized: "오늘 \(completedEventCount)건의 일정을 소화했으며, 총 \(timeStr)을 사용했습니다."))

            if let longest = pastEvents.filter({ !$0.isAllDay }).max(by: { $0.durationMinutes < $1.durationMinutes }) {
                let title = longest.title
                let dur = longest.durationMinutes
                parts.append(String(localized: "가장 긴 일정은 '\(title)'(\(dur)분)이었습니다."))
            }
        }

        if !completedTasks.isEmpty {
            parts.append(String(localized: "\(completedTasks.count)개의 할 일을 완료했습니다."))
        }
        if !pendingTasks.isEmpty {
            parts.append(String(localized: "아직 \(pendingTasks.count)개의 할 일이 남아있습니다."))
        }
        if !memos.isEmpty {
            parts.append(String(localized: "총 \(memos.count)건의 메모를 기록했습니다."))
        }

        return parts.joined(separator: " ")
    }
    
    // MARK: - 로컬 하이라이트 추출
    private func extractLocalHighlights(events: [CalendarEvent], completedTasks: [TaskItem], memos: [String]) -> [String] {

        var highlights: [String] = []

        // NLTagger로 키워드 추출
        let allText = (events.map { $0.title } + completedTasks.map { $0.title } + memos)
            .joined(separator: ". ")
        let keywords = extractKeywords(from: allText, count: 3)

        // 카테고리별 일정 하이라이트 (사용자 지정 카테고리 활용)
        let categoryGroups = Dictionary(grouping: events.filter { $0.category != UserCategory.defaultName }) { $0.category }
        if !categoryGroups.isEmpty {
            for (category, grouped) in categoryGroups.sorted(by: { $0.value.count > $1.value.count }).prefix(3) {
                let minutes = grouped.filter { !$0.isAllDay }.reduce(0) { $0 + $1.durationMinutes }
                let count = grouped.count
                if minutes > 0 {
                    highlights.append(String(localized: "📌 \(category) 관련 일정 \(count)건 (총 \(minutes)분)"))
                } else {
                    highlights.append(String(localized: "📌 \(category) 관련 일정 \(count)건"))
                }
            }
        } else {
            // 폴백: 키워드 기반 회의 수 체크 — 한·영 양쪽 keyword 매칭.
            let meetingCount = events.filter { event in
                let t = event.title.lowercased()
                return t.contains("회의") || t.contains("미팅") || t.contains("meeting")
            }.count
            if meetingCount > 0 {
                highlights.append(String(localized: "\(meetingCount)건의 회의에 참석했습니다"))
            }
        }

        // 바쁜 하루 체크
        let totalMinutes = events.filter { !$0.isAllDay }.reduce(0) { $0 + $1.durationMinutes }
        if totalMinutes > 240 {
            highlights.append(String(localized: "4시간 이상 일정에 투입되어 바쁜 하루였습니다"))
        }

        // 할 일 성과
        if completedTasks.count >= 5 {
            let count = completedTasks.count
            highlights.append(String(localized: "할 일 \(count)개를 완료하여 생산적인 하루였습니다"))
        } else if let topTask = completedTasks.first {
            let title = topTask.title
            let count = completedTasks.count
            highlights.append(String(localized: "'\(title)' 등 \(count)건을 완료했습니다"))
        }

        // 키워드
        if !keywords.isEmpty {
            let joined = keywords.joined(separator: ", ")
            highlights.append(String(localized: "주요 키워드: \(joined)"))
        }

        return Array(highlights.prefix(5))
    }
    
    // MARK: - 다음 할 일 추천
    // 우선수누이 높은 것 -> 마감 임박 -> 회의 후속 작업 -> 일반 미완료 순으로 3개를 추천
    private func recommendNextActions(pendingTasks: [TaskItem], events: [CalendarEvent]) -> [String] {
        
        var actions: [String] = []
        
        // 1) 우선순위 높은 항목
        let highPriority = pendingTasks.filter { $0.priority == 1 }
        for task in highPriority.prefix(2) {
            let title = task.title
            actions.append(String(localized: "🔴 \(title) (높은 우선순위)"))
        }

        // 2) 마감 임박 항목
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!.endOfDay
        let urgent = pendingTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due <= tomorrow && task.priority != 1
        }
        for task in urgent.prefix(2) {
            let title = task.title
            actions.append(String(localized: "⏰ \(title) (마감 임박)"))
        }

        // 3) 회의 후속 작업
        let hadMeetings = events.contains { event in
            let t = event.title.lowercased()
            return t.contains("회의") || t.contains("미팅") || t.contains("meeting")
        }
        if hadMeetings && actions.count < 3 {
            actions.append(String(localized: "📋 오늘 회의 내용 정리 및 액션 아이템 확인"))
        }

        // 4) 일반 미완료 항목으로 채움
        if actions.count < 3 {
            let remaining = pendingTasks
                .filter { task in !actions.contains(where: { $0.contains(task.title) }) }
                .prefix(3 - actions.count)
            for task in remaining {
                let title = task.title
                actions.append(String(localized: "📌 \(title)"))
            }
        }

        return Array(actions.prefix(3))
    }
    
    // MARK: - 카테고리 감지
    /// 사용자가 지정한 카테고리를 우선 사용하고, 없으면 기본값 반환
    private func detectCategory(events: [CalendarEvent], tasks: [TaskItem]) -> String {
        let explicitCategories = events
            .map { $0.category }
            .filter { $0 != UserCategory.defaultName }

        if !explicitCategories.isEmpty {
            let grouped = Dictionary(grouping: explicitCategories) { $0 }
            if let dominant = grouped.max(by: { $0.value.count < $1.value.count }) {
                return dominant.key
            }
        }

        return UserCategory.defaultName
    }
    
    // MARK: - 생산성 점수
    // 할 일 완료율(50%) + 일정 완료 체크율(30%) + 우선순위 달성률(20%)
    private func calculateProductivityScore(events: [CalendarEvent], completedTasks: [TaskItem], pendingTasks: [TaskItem], completedEventCount: Int = 0) -> Double {
        guard !events.isEmpty else { return 0.5 }
        return Double(completedEventCount) / Double(events.count)
    }
    
    // MARK: - NLTagger 키워드 추출
    /**
     NLTagger는 Apple의 온디바이스 NLP 엔진으로 서버 호출 없이
     명사/고유명사를 추출한다.
     "코드 리뷰", "디자인 회의" 같은 핵심 키워드를 빈도순으로 리턴한다
     */
    private func extractKeywords(from text: String, count: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var keywords: [String: Int] = [:]
        
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, range in
            if let tag,
               tag == .noun || tag == .personalName || tag == .organizationName {
                let word = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if word.count >= 2 {
                    keywords[word, default: 0] += 1
                }
            }
            return true
        }
        
        return keywords
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
    }
    
    // MARK: - 빠른 로컬 요약
    private func buildQuickSummaryLocally(events: [CalendarEvent], completedTasks: [TaskItem]) -> String {
        if events.isEmpty && completedTasks.isEmpty {
            return String(localized: "오늘은 기록된 활동이 없습니다.")
        }
        var parts: [String] = []
        if !events.isEmpty {
            let count = events.count
            parts.append(String(localized: "일정 \(count)건"))
        }
        if !completedTasks.isEmpty {
            let count = completedTasks.count
            parts.append(String(localized: "완료 \(count)건"))
        }
        let joined = parts.joined(separator: ", ")
        return String(localized: "오늘: \(joined)")
    }
}
