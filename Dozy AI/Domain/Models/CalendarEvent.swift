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
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let calendarName: String
    let calendarColorHex: String

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
