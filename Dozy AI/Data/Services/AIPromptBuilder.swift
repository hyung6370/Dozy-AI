//
//  AIPromptBuilder.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//
//  Foundation Models 로 보내는 prompt 빌더. section tag 는 한·영 공통으로 영문
//  ([Summary], [Highlights], ...) — AIResponseParser 와의 결합 면을 단순화하기 위해
//  language 와 무관하게 tag 자체는 고정. 모델이 응답할 *내용 언어* 만 locale 따라 분기.
//

import Foundation

enum AIPromptBuilder {

    // MARK: - Locale 판별

    /// 현재 locale 이 한국어인지 — `ko-KR`, `ko-Kore-KR` 등 ko 계열 모두 true.
    private static var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    // MARK: - 전체 업무 요약 프롬프트

    static func buildDailySummaryPrompt(
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String],
        date: Date = Date()
    ) -> String {

        var sections: [String] = []

        // 날짜 — formattedKorean 은 이미 locale-aware (ko: "5월 13일 (수)" / en: "May 13 (Wed)").
        let dateLabel = isKorean ? "업무 데이터" : "Daily Data"
        sections.append("# \(date.formattedKorean) \(dateLabel)")

        // 캘린더 일정
        if !events.isEmpty {
            let lines = events.map { event in
                let catLabel = event.category != "일반" ? " [\(event.category)]" : ""
                let minLabel = isKorean ? "\(event.durationMinutes)분" : "\(event.durationMinutes) min"
                return "- \(event.contextString) [\(minLabel)]\(catLabel)"
            }
            let header = isKorean
                ? "## 오늘의 일정 (\(events.count)건)"
                : "## Today's Events (\(events.count))"
            sections.append("\(header)\n\(lines.joined(separator: "\n"))")

            // 카테고리별 분포
            let catGroups = Dictionary(grouping: events) { $0.category }
                .filter { $0.key != "일반" }
            if !catGroups.isEmpty {
                let catLines = catGroups
                    .sorted { $0.value.count > $1.value.count }
                    .map { isKorean ? "\($0.key): \($0.value.count)건" : "\($0.key): \($0.value.count)" }
                let catHeader = isKorean ? "## 카테고리별 일정 분포" : "## Distribution by Category"
                sections.append("\(catHeader)\n\(catLines.joined(separator: ", "))")
            }
        } else {
            sections.append(isKorean ? "## 오늘의 일정\n- 등록된 일정 없음" : "## Today's Events\n- No events")
        }

        // 완료한 할 일
        if !completedTasks.isEmpty {
            let lines = completedTasks.map { $0.contextString }
            let header = isKorean
                ? "## 완료한 할 일 (\(completedTasks.count)건)"
                : "## Completed Tasks (\(completedTasks.count))"
            sections.append("\(header)\n\(lines.joined(separator: "\n"))")
        }

        // 미완료 할 일
        if !pendingTasks.isEmpty {
            let lines = pendingTasks.prefix(10).map { task in
                let prefix = "- ⏳ \(task.title)"
                guard task.priority > 0 else { return prefix }
                let priorityTag = isKorean
                    ? " [우선순위: \(task.priorityString)]"
                    : " [Priority: \(task.priorityString)]"
                return prefix + priorityTag
            }
            let header = isKorean
                ? "## 아직 미완료인 할 일 (\(pendingTasks.count)건)"
                : "## Pending Tasks (\(pendingTasks.count))"
            sections.append("\(header)\n\(lines.joined(separator: "\n"))")
        }

        // 메모
        if !memos.isEmpty {
            let lines = memos.map { "- 📝 \($0)" }
            let header = isKorean ? "## 사용자 메모" : "## User Memos"
            sections.append("\(header)\n\(lines.joined(separator: "\n"))")
        }

        // AI 지시사항 — section tag 는 영문 공통.
        sections.append(instruction)

        return sections.joined(separator: "\n\n")
    }

    /// 모델에게 주는 형식 지시사항. section tag 는 영문 공통 ([Summary], [Highlights], ...)
    /// 으로 parser 와 일치시키되, *응답 내용 언어* 와 자연어 설명은 사용자 locale 에 맞춤.
    private static var instruction: String {
        if isKorean {
            return """

            ---
            위 데이터를 분석하여 아래 형식으로 업무 보고서를 작성해주세요.
            반드시 아래 형식과 섹션 이름(영문)을 정확히 지켜주세요. 응답 본문은 한국어로 작성:

            [Summary]
            오늘 하루를 2~3문장으로 요약

            [Highlights]
            - 핵심 성과나 주요 활동 3~5개

            [Next Actions]
            - 내일 우선적으로 해야 할 일 3개 (미완료 항목과 오늘 흐름을 고려)

            [Category]
            오늘의 주요 업무 카테고리 하나만 (개발/회의/리뷰/기획/문서/일반 중 택1)

            [Score]
            0.0~1.0 사이의 숫자 (완료한 일과 일정 소화율 기준)
            """
        } else {
            return """

            ---
            Analyze the data above and write a daily work report in the exact format below.
            Keep the section names in English as shown. Write the body content in English:

            [Summary]
            Summarize the day in 2-3 sentences.

            [Highlights]
            - 3-5 key achievements or notable activities

            [Next Actions]
            - 3 tasks to prioritize tomorrow (consider pending items and today's flow)

            [Category]
            Pick exactly one primary category for the day (e.g., Development, Meeting, Review, Planning, Documentation, General).

            [Score]
            A number between 0.0 and 1.0 based on completed work and event throughput.
            """
        }
    }

    // MARK: - 빠른 한줄 요약 프롬프트

    static func buildQuickSummaryPrompt(
        events: [CalendarEvent],
        completedTasks: [TaskItem]
    ) -> String {

        if isKorean {
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
        } else {
            let eventPart = events.isEmpty
                ? "No events"
                : events.prefix(5).map { $0.title }.joined(separator: ", ")
            let taskPart = completedTasks.isEmpty
                ? "No completed tasks"
                : completedTasks.prefix(5).map { $0.title }.joined(separator: ", ")
            return """
            Today's events: \(eventPart)
            Completed: \(taskPart)

            Summarize the above in one short English sentence (under 80 characters).
            """
        }
    }
}
