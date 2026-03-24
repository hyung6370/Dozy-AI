//
//  TaskItem.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import EventKit

struct TaskItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let isCompleted: Bool
    let completedDate: Date?
    let dueDate: Date?
    let priority: Int          // 0=없음, 1=높음, 5=중간, 9=낮음 (EKReminder 규칙)
    let listName: String       // 어떤 리마인더 목록에 속하는지
    let notes: String?
    
    /// EKReminder → TaskItem 변환
    init(from reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? "제목 없음"
        self.isCompleted = reminder.isCompleted
        self.completedDate = reminder.completionDate
        self.dueDate = reminder.dueDateComponents?.date
        self.priority = reminder.priority
        self.listName = reminder.calendar?.title ?? ""
        self.notes = reminder.notes
    }
    
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
