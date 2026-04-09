//
//  DozyEvent.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import SwiftData

@Model
final class DozyEvent {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date
    var recurrenceRule: String = "none" // "none" | "daily" | "weekly" | "monthly" | "yearly"
    var isCompleted: Bool = false
    var recurrenceEndDate: Date? = nil
    var notificationMinutesBefore: Int = -1 // -1: 없음
    var memos: [String] = []
    var priority: Int = 0
    var isPinned: Bool = false
    var category: String = "일반"

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        colorHex: String = "#007AFF",
        recurrenceRule: String = "none",
        recurrenceEndDate: Date? = nil,
        notificationMinutesBefore: Int = -1,
        priority: Int = 0,
        isPinned: Bool = false,
        category: String = "일반"
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.colorHex = colorHex
        self.createdAt = Date()
        self.updatedAt = Date()
        self.recurrenceRule = recurrenceRule
        self.recurrenceEndDate = recurrenceEndDate
        self.notificationMinutesBefore = notificationMinutesBefore
        self.priority = priority
        self.isPinned = isPinned
        self.category = category
    }
    
    // MARK: - 반복 헬퍼
    
    // 원본 날짜 이후에 date에 반복 발생하는지 여부
    func occursOn(_ date: Date) -> Bool {
        guard recurrenceRule != "none" else { return false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let target = cal.startOfDay(for: date)
        guard target > start else { return false }
        if let end = recurrenceEndDate, target > cal.startOfDay(for: end) { return false }
        
        switch recurrenceRule {
        case "daily": return true
        case "weekly": return cal.component(.weekday, from: start) == cal.component(.weekday, from: target)
        case "monthly": return cal.component(.day, from: start) == cal.component(.day, from: target)
        case "yearly":
            let s = cal.dateComponents([.month, .day], from: start)
            let t = cal.dateComponents([.month, .day], from: target)
            return s.month == t.month && s.day == t.day
        default: return false
        }
    }
    
    // MARK: - CalendarEvent 변환
    
    // date 전달 시 반복 인스턴스 날짜로 조정된 CalendarEvent 반환
    func toCalendarEvent(for date: Date? = nil) -> CalendarEvent {
        var start = startDate
        var end = endDate
        if let date {
            let cal = Calendar.current
            let diff = cal.dateComponents([.day],
                                          from: cal.startOfDay(for: startDate),
                                          to: cal.startOfDay(for: date)).day ?? 0
            start = cal.date(byAdding: .day, value: diff, to: startDate) ?? startDate
            end = cal.date(byAdding: .day, value: diff, to: endDate) ?? endDate
        }
        return CalendarEvent(
            id: id,
            calendarId: nil,
            title: title,
            startDate: start,
            endDate: end,
            location: location,
            notes: notes,
            isAllDay: isAllDay,
            calendarName: "Dozy",
            calendarColorHex: colorHex,
            source: .dozy,
            priority: priority,
            isPinned: isPinned,
            category: category
        )
    }

    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: id,
            calendarId: nil,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            isAllDay: isAllDay,
            calendarName: "Dozy",
            calendarColorHex: colorHex,
            source: .dozy,
            priority: priority,
            isPinned: isPinned,
            category: category
        )
    }
}
