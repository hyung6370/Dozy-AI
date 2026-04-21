//
//  NaverCalendarListResponse.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/31/26.
//

import Foundation

// MARK: - Calendar List
struct NaverCalendarListResponse: Decodable {
    let calendars: [NaverCalendarItem]?
    
    enum CodingKeys: String, CodingKey {
        case calendars = "calendars"
    }
}

struct NaverCalendarItem: Decodable {
    let calendarId: String
    let calendarName: String
    let backgroundColor: String?
}

// MARK: - Events

struct NaverCalendarResponse: Decodable {
    let calendars: [NaverCalendarWithSchedules]?
}

struct NaverCalendarWithSchedules: Decodable {
    let calendarId: String?
    let calendarName: String?
    let schedules: [NaverEventItem]?
}

struct NaverEventItem: Decodable {
    let scheduleId: String?
    let summary: String?
    let dtstart: NaverDateTime?
    let dtend: NaverDateTime?
    let location: String?
    let description: String?
    let isAllDay: String?
    
    func toCalendarEvent(calendarName: String, colorHex: String) -> CalendarEvent? {
        guard let start = dtstart?.toDate(),
              let end = dtend?.toDate() else { return nil }
        
        return CalendarEvent(
            id: scheduleId ?? UUID().uuidString,
            calendarId: nil,
            title: summary ?? "제목 없음",
            startDate: start,
            endDate: end,
            location: location,
            notes: description,
            isAllDay: isAllDay == "Y",
            calendarName: calendarName,
            calendarColorHex: colorHex,
            source: .naver,
            priority: 0,
            isPinned: false,
            category: "일반",
            sharedCalendarID: nil,
            ownerID: nil,
            externalSource: nil,
            externalEventID: nil,
            externalDeleted: false
        )
    }
}

struct NaverDateTime: Decodable {
    let dateTime: String?   // "20240101T090000Z"
    let date: String?       // "20240101"
    
    func toDate() -> Date? {
        if let dt = dateTime {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            fmt.timeZone = TimeZone(identifier: "UTC")
            return fmt.date(from: dt)
        }
        if let d = date {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd"
            fmt.timeZone = .current
            return fmt.date(from: d)
        }
        return nil
    }
}
