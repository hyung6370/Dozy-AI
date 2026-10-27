//
//  TodayEventCache.swift
//  Dozy AI
//
//  위젯과 메인 앱 사이 데이터 다리. HomeViewModel 이 오늘의 머지된 일정
//  (Apple + Google + Dozy + Holiday) 을 이 @Model 로 upsert 하면 위젯이
//  App Group container 의 SwiftData store 에서 직접 읽어 표시한다.
//
//  Apple / Google 캘린더 이벤트는 EventKit / Google API 에서 실시간 fetch 라
//  SwiftData 에 직접 들어가지 않음 → 위젯에서 볼 수 없음. 이 캐시 모델이 그
//  격차를 메운다. 사용자가 메인 앱을 한 번 열어 loadTodayData() 가 fire 하면
//  캐시가 갱신되고 위젯이 다음 timeline refresh 시 새 데이터를 본다.
//

import Foundation
import SwiftData

@Model
final class TodayEventCache {
    /// 원본 CalendarEvent.id 그대로 사용 (Apple = EKEvent identifier,
    /// Google = google event id, Dozy = UUID, Holiday = 합성 ID).
    @Attribute(.unique) var id: String

    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var colorHex: String
    var isCompleted: Bool
    var isPinned: Bool

    /// 캐시가 어느 시점의 데이터인지 (메인 앱 loadTodayData 호출 시각).
    /// 위젯이 오늘 데이터인지 검증할 때 사용. 자정 넘기면 위젯 timeline 이
    /// 새 entry 요청 → 메인 앱 호출 없이도 cachedAt < 오늘 시작 이면 빈 상태로 fallback.
    var cachedAt: Date

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        colorHex: String,
        isCompleted: Bool,
        isPinned: Bool,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.colorHex = colorHex
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.cachedAt = cachedAt
    }
}
