//
//  CalendarEvent.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture]
//  Domain 모델은 프레임워크(EventKit)를 알아서는 안 됩니다.
//  EKEvent → CalendarEvent 변환(Mapping)은 Data 계층(CalendarService)이 담당합니다.

import Foundation

struct CalendarEvent: Identifiable, Codable, Hashable {
    let id: String
    let calendarId: String?
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let calendarName: String
    let calendarColorHex: String
    let source: CalendarSource
    let priority: Int
    let isPinned: Bool
    let category: String
    let sharedCalendarID: String?
    let ownerID: String?    // Dozy 이벤트 전용. Apple/Google 이벤트는 nil

    var isShared: Bool { sharedCalendarID != nil }

    // Swift가 자동으로 memberwise init을 생성합니다.
    // init(id:title:startDate:endDate:location:notes:isAllDay:calendarName:calendarColorHex:)

    /// 소요 시간 (분)
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// "오후 2:00 ~ 3:30" 형태
    var timeRangeString: String {
        if isAllDay { return "종일" }
        return "\(startDate.formattedTime) ~ \(endDate.formattedTime)"
    }

    /// AI 프롬프트용 요약 텍스트
    var contextString: String {
        var text = "[\(timeRangeString)] \(title)"
        if let location, !location.isEmpty {
            text += " (장소: \(location))"
        }
        return text
    }
}

extension CalendarEvent {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        calendarId = try c.decodeIfPresent(String.self, forKey: .calendarId)
        title = try c.decode(String.self, forKey: .title)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        isAllDay = try c.decode(Bool.self, forKey: .isAllDay)
        calendarName = try c.decode(String.self, forKey: .calendarName)
        calendarColorHex = try c.decode(String.self, forKey: .calendarColorHex)
        source = try c.decodeIfPresent(CalendarSource.self, forKey: .source) ?? .apple
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "일반"
        sharedCalendarID = try c.decodeIfPresent(String.self, forKey: .sharedCalendarID)
        ownerID = try c.decodeIfPresent(String.self, forKey: .ownerID)
    }
}

extension CalendarEvent {
    func applying(_ settings: EventDisplaySettings?) -> CalendarEvent {
        guard let settings else { return self }
        return CalendarEvent(
            id: id, calendarId: calendarId, title: title,
            startDate: startDate, endDate: endDate,
            location: location, notes: notes, isAllDay: isAllDay,
            calendarName: calendarName, calendarColorHex: calendarColorHex,
            source: source,
            priority: settings.priority,
            isPinned: settings.isPinned,
            category: settings.category == UserCategory.defaultName ? category : settings.category,
            sharedCalendarID: sharedCalendarID,
            ownerID: ownerID
        )
    }
}
