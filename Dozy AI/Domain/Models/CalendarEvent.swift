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

    /// Apple/Google 원본 이벤트를 Dozy 공유 캘린더로 미러링했을 때만 세팅됨.
    /// - source == .dozy && externalSource != nil → 미러 스냅샷
    /// - source == .apple/.google → 외부 원본 (externalSource는 nil)
    let externalSource: CalendarSource?
    let externalEventID: String?
    /// 원본 기기에서 원본이 더이상 조회되지 않을 때 true (파트너 UI의 "원본 삭제됨" 배지용).
    let externalDeleted: Bool

    // 기본값 — 기존 호출부가 새 필드를 몰라도 컴파일되도록.
    init(
        id: String, calendarId: String?, title: String,
        startDate: Date, endDate: Date,
        location: String?, notes: String?, isAllDay: Bool,
        calendarName: String, calendarColorHex: String,
        source: CalendarSource, priority: Int, isPinned: Bool, category: String,
        sharedCalendarID: String? = nil, ownerID: String? = nil,
        externalSource: CalendarSource? = nil,
        externalEventID: String? = nil,
        externalDeleted: Bool = false
    ) {
        self.id = id
        self.calendarId = calendarId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.calendarColorHex = calendarColorHex
        self.source = source
        self.priority = priority
        self.isPinned = isPinned
        self.category = category
        self.sharedCalendarID = sharedCalendarID
        self.ownerID = ownerID
        self.externalSource = externalSource
        self.externalEventID = externalEventID
        self.externalDeleted = externalDeleted
    }

    var isShared: Bool { sharedCalendarID != nil }

    /// Apple/Google 원본을 Dozy에 복제한 스냅샷인지 여부.
    var isExternalMirror: Bool { externalSource != nil && externalEventID != nil }

    /// 사용자가 직접 수정·삭제할 수 없는 이벤트. 공휴일은 공공데이터 기반 read-only.
    var isReadOnly: Bool { source == .holiday }

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
            text += " " + String(localized: "(장소: \(location))")
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
        externalSource = try c.decodeIfPresent(CalendarSource.self, forKey: .externalSource)
        externalEventID = try c.decodeIfPresent(String.self, forKey: .externalEventID)
        externalDeleted = try c.decodeIfPresent(Bool.self, forKey: .externalDeleted) ?? false
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
            ownerID: ownerID,
            externalSource: externalSource,
            externalEventID: externalEventID,
            externalDeleted: externalDeleted
        )
    }
}
