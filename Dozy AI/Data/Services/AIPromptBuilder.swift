//
//  AIPromptBuilder.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//

import Foundation

enum AIPromptBuilder {
    
    // MARK: - 전체 업무 요약 프롬프트
    
    static func buildDailySummaryPrompt(
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String],
        date: Date = Date()
    ) -> String {
        
        var sections: [String] = []
        
        // 날짜
        sections.append("# \(date.formattedKorean) 업무 데이터")
        
        // 캘린더 일정
        if !events.isEmpty {
            let lines = events.map { "- \($0.contextString) [\($0.durationMinutes)분]" }
            sections.append(
                "## 오늘의 일정 (\(events.count)건)\n\(lines.joined(separator: "\n"))"
            )
        } else {
            sections.append("## 오늘의 일정\n- 등록된 일정 없음")
        }
        
        // 완료한 할 일
        if !completedTasks.isEmpty {
            let lines = completedTasks.map { $0.contextString }
            sections.append(
                "## 완료한 할 일 (\(completedTasks.count)건)\n\(lines.joined(separator: "\n"))"
            )
        }
        
        // 미완료 할 일
        if !pendingTasks.isEmpty {
            let lines = pendingTasks.prefix(10).map { task in
                "- ⏳ \(task.title)" + (task.priority > 0 ? " [우선순위: \(task.priorityString)]" : "")
            }
            sections.append(
                "## 아직 미완료인 할 일 (\(pendingTasks.count)건)\n\(lines.joined(separator: "\n"))"
            )
        }
        
        // 메모
        if !memos.isEmpty {
            let lines = memos.map { "- 📝 \($0)" }
            sections.append(
                "## 사용자 메모\n\(lines.joined(separator: "\n"))"
            )
        }
        
        // AI 지시사항
        let instruction = """
        
        ---
        위 데이터를 분석하여 아래 형식으로 업무 보고서를 작성해주세요.
        반드시 아래 형식을 정확히 지켜주세요:
        
        [요약]
        오늘 하루를 2~3문장으로 요약
        
        [하이라이트]
        - 핵심 성과나 주요 활동 3~5개
        
        [추천 할 일]
        - 내일 우선적으로 해야 할 일 3개 (미완료 항목과 오늘 흐름을 고려)
        
        [카테고리]
        오늘의 주요 업무 카테고리 하나만 (개발/회의/리뷰/기획/문서/일반 중 택1)
        
        [생산성 점수]
        0.0~1.0 사이의 숫자 (완료한 일과 일정 소화율 기준)
        """
        
        sections.append(instruction)
        
        return sections.joined(separator: "\n\n")
    }
    
    // MARK: - 빠른 한줄 요약 프롬프트
    
    static func buildQuickSummaryPrompt(
        events: [CalendarEvent],
        completedTasks: [TaskItem]
    ) -> String {
        
        let eventPart = events.isEmpty
            ? "일정 없음"
            : events.prefix(5).map { $0.title }.joined(separator: ", ")
        
        let taskPart = completedTasks.isEmpty
            ? "완료한 일 없음"
            : completedTasks.prefix(5).map { $0.title }.joined(separator: ", ")
        
        return """
        오늘 일정: \(eventPart)
        완료한 일: \(taskPart)
        
        위 내용을 한 문장으로 요약해주세요. (30자 이내)
        """
    }
}
