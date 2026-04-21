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
    var excludedDates: [Date] = []
    var sharedCalendarID: String? = nil
    /// 이벤트 생성자(소유자)의 user_id. 공유 캘린더에서 파트너 이벤트를 덮어쓰지 않기 위해 추적.
    /// nil = 로컬 생성 후 아직 동기화되지 않음 (업로드 시 현재 사용자로 간주)
    var ownerID: String? = nil

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
        category: String = "일반",
        sharedCalendarID: String? = nil,
        ownerID: String? = nil
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
        self.sharedCalendarID = sharedCalendarID
        self.ownerID = ownerID
    }

    var isShared: Bool { sharedCalendarID != nil }
    
    // MARK: - 반복 헬퍼

    /// 다일 반복 일정을 포함하여, date를 포함하는 반복 인스턴스의 시작일을 반환
    /// 해당 날짜에 반복 인스턴스가 없으면 nil
    func occurrenceStart(for date: Date) -> Date? {
        guard recurrenceRule != "none" else { return nil }
        let cal = Calendar.current
        let eventStart = cal.startOfDay(for: startDate)
        let target = cal.startOfDay(for: date)
        guard target >= eventStart else { return nil }

        let durationDays = max(0, cal.dateComponents([.day], from: eventStart, to: cal.startOfDay(for: endDate)).day ?? 0)

        // target이 어떤 반복 인스턴스의 N번째 날인지 확인 (0 = 시작일, 1 = 둘째날, ...)
        for dayOffset in 0...durationDays {
            guard let candidateStart = cal.date(byAdding: .day, value: -dayOffset, to: target) else { continue }
            let cs = cal.startOfDay(for: candidateStart)
            guard cs >= eventStart else { continue }
            if let end = recurrenceEndDate, cs > cal.startOfDay(for: end) { continue }
            if excludedDates.contains(where: { cal.isDate($0, inSameDayAs: candidateStart) }) { continue }

            let matches: Bool
            switch recurrenceRule {
            case "daily": matches = true
            case "weekly": matches = cal.component(.weekday, from: eventStart) == cal.component(.weekday, from: cs)
            case "monthly": matches = cal.component(.day, from: eventStart) == cal.component(.day, from: cs)
            case "yearly":
                let s = cal.dateComponents([.month, .day], from: eventStart)
                let t = cal.dateComponents([.month, .day], from: cs)
                matches = s.month == t.month && s.day == t.day
            default: matches = false
            }
            if matches { return cs }
        }
        return nil
    }

    func occursOn(_ date: Date) -> Bool {
        occurrenceStart(for: date) != nil
    }

    // MARK: - CalendarEvent 변환

    // date 전달 시 반복 인스턴스의 시작일 기준으로 조정된 CalendarEvent 반환
    func toCalendarEvent(for date: Date? = nil) -> CalendarEvent {
        var start = startDate
        var end = endDate
        if let date {
            let cal = Calendar.current
            // 다일 반복 일정: 해당 인스턴스의 시작일 기준으로 날짜 조정
            let occStart = occurrenceStart(for: date) ?? cal.startOfDay(for: date)
            let diff = cal.dateComponents([.day],
                                          from: cal.startOfDay(for: startDate),
                                          to: occStart).day ?? 0
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
            category: category,
            sharedCalendarID: sharedCalendarID,
            ownerID: ownerID
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
            category: category,
            sharedCalendarID: sharedCalendarID,
            ownerID: ownerID
        )
    }
}
