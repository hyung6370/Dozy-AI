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

    /// 우선순위를 한글로 변환
    var priorityString: String {
        switch priority {
        case 1: return "높음"
        case 5: return "중간"
        case 9: return "낮음"
        default: return "없음"
        }
    }

    /// AI 프롬프트용 요약 텍스트
    var contextString: String {
        var text = "✅ \(title)"
        if priority > 0 {
            text += " [우선순위: \(priorityString)]"
        }
        return text
    }
}
