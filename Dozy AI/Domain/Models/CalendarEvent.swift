//
//  CalendarEvent.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import EventKit

struct CalendarEvent: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let calendarName: String
    let calendarColorHex: String
    
    /// EKEvent → CalendarEvent 변환
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "제목 없음"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.isAllDay = ekEvent.isAllDay
        self.calendarName = ekEvent.calendar?.title ?? ""
        // CGColor → Hex 변환
        if let cgColor = ekEvent.calendar?.cgColor,
           let components = cgColor.components, components.count >= 3 {
            let r = Int(components[0] * 255)
            let g = Int(components[1] * 255)
            let b = Int(components[2] * 255)
            self.calendarColorHex = String(format: "#%02X%02X%02X", r, g, b)
        } else {
            self.calendarColorHex = "#007AFF"
        }
    }
    
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
