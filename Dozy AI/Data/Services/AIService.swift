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
            memos: memos
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
    private func buildLocalSummaryText(events: [CalendarEvent], completedTasks: [TaskItem], pendingTasks: [TaskItem], memos: [String]) -> String {
        
        var parts: [String] = []
        
        if events.isEmpty {
            parts.append("오늘은 등록된 일정이 없었습니다.")
        } else {
            let totalMinutes = events
                .filter { !$0.isAllDay }
                .reduce(0) { $0 + $1.durationMinutes }
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            let timeStr = hours > 0 ? "\(hours)시간 \(mins)분" : "\(mins)분"
            
            parts.append("오늘 \(events.count)건의 일정을 소화했으며, 총 \(timeStr)을 사용했습니다.")
            
            if let longest = events.filter({ !$0.isAllDay }).max(by: { $0.durationMinutes < $1.durationMinutes }) {
                parts.append("가장 긴 일정은 '\(longest.title)'(\(longest.durationMinutes)분)이었습니다.")
            }
        }
        
        if !completedTasks.isEmpty {
            parts.append("\(completedTasks.count)개의 할 일을 완료했습니다.")
        }
        if !pendingTasks.isEmpty {
            parts.append("아직 \(pendingTasks.count)개의 할 일이 남아있습니다.")
        }
        if !memos.isEmpty {
            parts.append("총 \(memos.count)건의 메모를 기록했습니다.")
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
        let categoryGroups = Dictionary(grouping: events.filter { $0.category != WorkCategory.general.rawValue }) { $0.category }
        if !categoryGroups.isEmpty {
            for (category, grouped) in categoryGroups.sorted(by: { $0.value.count > $1.value.count }).prefix(3) {
                let emoji = WorkCategory(rawValue: category)?.emoji ?? "📌"
                let minutes = grouped.filter { !$0.isAllDay }.reduce(0) { $0 + $1.durationMinutes }
                if minutes > 0 {
                    highlights.append("\(emoji) \(category) 관련 일정 \(grouped.count)건 (총 \(minutes)분)")
                } else {
                    highlights.append("\(emoji) \(category) 관련 일정 \(grouped.count)건")
                }
            }
        } else {
            // 폴백: 키워드 기반 회의 수 체크
            let meetingCount = events.filter { event in
                let t = event.title.lowercased()
                return t.contains("회의") || t.contains("미팅") || t.contains("meeting")
            }.count
            if meetingCount > 0 {
                highlights.append("\(meetingCount)건의 회의에 참석했습니다")
            }
        }

        // 바쁜 하루 체크
        let totalMinutes = events.filter { !$0.isAllDay }.reduce(0) { $0 + $1.durationMinutes }
        if totalMinutes > 240 {
            highlights.append("4시간 이상 일정에 투입되어 바쁜 하루였습니다")
        }

        // 할 일 성과
        if completedTasks.count >= 5 {
            highlights.append("할 일 \(completedTasks.count)개를 완료하여 생산적인 하루였습니다")
        } else if let topTask = completedTasks.first {
            highlights.append("'\(topTask.title)' 등 \(completedTasks.count)건을 완료했습니다")
        }

        // 키워드
        if !keywords.isEmpty {
            highlights.append("주요 키워드: \(keywords.joined(separator: ", "))")
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
            actions.append("🔴 \(task.title) (높은 우선순위)")
        }
        
        // 2) 마감 임박 항목
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!.endOfDay
        let urgent = pendingTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due <= tomorrow && task.priority != 1
        }
        for task in urgent.prefix(2) {
            actions.append("⏰ \(task.title) (마감 임박)")
        }
        
        // 3) 회의 후속 작업
        let hadMeetings = events.contains { event in
            let t = event.title.lowercased()
            return t.contains("회의") || t.contains("미팅") || t.contains("meeting")
        }
        if hadMeetings && actions.count < 3 {
            actions.append("📋 오늘 회의 내용 정리 및 액션 아이템 확인")
        }
        
        // 4) 일반 미완료 항목으로 채움
        if actions.count < 3 {
            let remaining = pendingTasks
                .filter { task in !actions.contains(where: { $0.contains(task.title) }) }
                .prefix(3 - actions.count)
            for task in remaining {
                actions.append("📌 \(task.title)")
            }
        }
        
        return Array(actions.prefix(3))
    }
    
    // MARK: - 카테고리 감지
    /// 사용자가 지정한 카테고리를 우선 사용하고, 없으면 키워드 기반 폴백
    private func detectCategory(events: [CalendarEvent], tasks: [TaskItem]) -> String {
        // 1) 사용자가 명시적으로 지정한 카테고리 집계 ("일반" 제외)
        let explicitCategories = events
            .map { $0.category }
            .filter { $0 != WorkCategory.general.rawValue }

        if !explicitCategories.isEmpty {
            let grouped = Dictionary(grouping: explicitCategories) { $0 }
            if let dominant = grouped.max(by: { $0.value.count < $1.value.count }) {
                return dominant.key
            }
        }

        // 2) 폴백: 키워드 기반 감지
        let allTitles = (events.map { $0.title } + tasks.map { $0.title })
            .joined(separator: " ")
            .lowercased()

        let keywords: [(WorkCategory, [String])] = [
            (.meeting, ["회의", "미팅", "meeting", "standup", "sync", "1:1", "데일리"]),
            (.review, ["리뷰", "review", "검토", "PR", "코드리뷰", "피드백"]),
            (.development, ["개발", "코딩", "dev", "sprint", "배포", "deploy", "버그", "구현"]),
            (.planning, ["기획", "플래닝", "planning", "브레인스토밍", "로드맵"]),
            (.documentation, ["문서", "doc", "작성", "wiki", "정리", "보고서"])
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
    
    // MARK: - 생산성 점수
    // 할 일 완료율(50%) + 일정 완료 체크율(30%) + 우선순위 달성률(20%)
    private func calculateProductivityScore(events: [CalendarEvent], completedTasks: [TaskItem], pendingTasks: [TaskItem], completedEventCount: Int = 0) -> Double {

        var score = 0.0

        // 1) 할 일 완료율 (50%) — 완료한 할 일 / 전체 할 일
        let totalTasks = completedTasks.count + pendingTasks.count
        if totalTasks > 0 {
            score += (Double(completedTasks.count) / Double(totalTasks)) * 0.5
        } else {
            score += 0.25
        }

        // 2) 일정 완료 체크율 (30%) — 완료 체크한 일정 / 전체 일정
        if !events.isEmpty {
            score += (Double(completedEventCount) / Double(events.count)) * 0.3
        } else {
            score += 0.15
        }

        // 3) 우선순위 달성률 (20%) — 우선순위가 있는 할 일 중 완료된 비율
        let highPriorityCompleted = completedTasks.filter { $0.priority > 0 }.count
        let highPriorityPending = pendingTasks.filter { $0.priority > 0 }.count
        let totalHighPriority = highPriorityCompleted + highPriorityPending
        if totalHighPriority > 0 {
            score += (Double(highPriorityCompleted) / Double(totalHighPriority)) * 0.2
        } else {
            score += 0.1
        }

        return min(max(score, 0.0), 1.0)
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
            return "오늘은 기록된 활동이 없습니다."
        }
        var parts: [String] = []
        if !events.isEmpty { parts.append("일정 \(events.count)건") }
        if !completedTasks.isEmpty { parts.append("완료 \(completedTasks.count)건") }
        return "오늘: \(parts.joined(separator: ", "))"
    }
}
