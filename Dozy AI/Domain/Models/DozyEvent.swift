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
    
    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        colorHex: String = "#007AFF"
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
    }
    
    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            isAllDay: isAllDay,
            calendarName: "Dozy",
            calendarColorHex: colorHex,
            source: .dozy
        )
    }
}
