//
//  GoogleCalendarDTO.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation

// MARK: - Calendar List
struct GoogleCalendarListResponse: Decodable {
    let items: [GoogleCalendarItem]?
}

struct GoogleCalendarItem: Decodable {
    let id: String
    let summary: String
    let backgroundColor: String?
    let selected: Bool?
    let accessRole: String?
}

// MARK: - Events

struct GoogleEventsResponse: Decodable {
    let items: [GoogleEventItem]?
    let nextPageToken: String?
}

struct GoogleEventItem: Decodable {
    let id: String?
    let summary: String?
    let start: GoogleEventDateTime?
    let end: GoogleEventDateTime?
    let location: String?
    let description: String?
    let status: String?

    func toCalendarEvent(calendarName: String, colorHex: String, calendarId: String) -> CalendarEvent? {
        guard let start, let end else { return nil }
        if status == "cancelled" { return nil }

        let isAllDay = start.dateOnly != nil
        let startDate: Date
        let endDate: Date

        if isAllDay {
            guard let s = start.dateOnly, let e = end.dateOnly else { return nil }
            startDate = s
            endDate = e
        } else {
            guard let s = start.dateTime, let e = end.dateTime else { return nil }
            startDate = s
            endDate = e
        }

        return CalendarEvent(
            id: id ?? UUID().uuidString,
            calendarId: calendarId,
            title: summary ?? "제목 없음",
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: description,
            isAllDay: isAllDay,
            calendarName: calendarName,
            calendarColorHex: colorHex,
            source: .google,
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

struct GoogleEventDateTime: Decodable {
    let dateTime: Date? // timed: "2024-01-01T09:00:00+09:00"
    let dateOnly: Date? // all-day: "2024-01-01"
    
    enum CodingKeys: String, CodingKey {
        case dateTime
        case date
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let str = try container.decodeIfPresent(String.self, forKey: .dateTime) {
            let full = ISO8601DateFormatter()
            full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            dateTime = full.date(from: str) ?? ISO8601DateFormatter().date(from: str)
        } else {
            dateTime = nil
        }
        
        if let str = try container.decodeIfPresent(String.self, forKey: .date) {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = .current
            dateOnly = fmt.date(from: str)
        } else {
            dateOnly = nil
        }
    }
}
