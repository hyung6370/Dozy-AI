//
//  TaskItem.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture]
//  Domain 모델은 프레임워크(EventKit)를 알아서는 안 됩니다.
//  EKReminder → TaskItem 변환(Mapping)은 Data 계층(ReminderService)이 담당합니다.

import Foundation

struct TaskItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let isCompleted: Bool
    let completedDate: Date?
    let dueDate: Date?
    let priority: Int      // 0=없음, 1=높음, 5=중간, 9=낮음 (EKReminder 규칙)
    let listName: String
    let notes: String?

    // Swift가 자동으로 memberwise init을 생성합니다.
    // init(id:title:isCompleted:completedDate:dueDate:priority:listName:notes:)

    /// 우선순위 label — 현재 locale 기반 (ko: 높음/중간/낮음/없음, en: High/Medium/Low/None).
    /// TaskRow 등 UI 와 AI prompt context 양쪽에서 공유.
    var priorityString: String {
        switch priority {
        case 1: return String(localized: "높음")
        case 5: return String(localized: "중간")
        case 9: return String(localized: "낮음")
        default: return String(localized: "없음")
        }
    }

    /// AI 프롬프트용 요약 텍스트 — Foundation Models 입력 context.
    var contextString: String {
        var text = "✅ \(title)"
        if priority > 0 {
            let p = priorityString
            text += " " + String(localized: "[우선순위: \(p)]")
        }
        return text
    }
}
