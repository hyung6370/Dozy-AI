//
//  NotificationRecord.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import Foundation
import SwiftData

@Model
final class NotificationRecord {
    @Attribute(.unique) var id: UUID
    var eventID: String
    var eventTitle: String
    var body: String
    var deliveryDate: Date
    var eventStartDate: Date = Date()
    var isRead: Bool
    /// "reminder" — 시간 기반 로컬 알림 (기존 동작)
    /// "shared"  — 파트너가 공유 캘린더에 일정 등록한 경우 카드 알림
    var kind: String = "reminder"
    /// 공유 알림에서 보낸 사람(파트너) 닉네임. reminder 는 nil.
    var senderName: String? = nil

    init(
        eventID: String,
        eventTitle: String,
        body: String,
        deliveryDate: Date,
        eventStartDate: Date,
        kind: String = "reminder",
        senderName: String? = nil
    ) {
        self.id = UUID()
        self.eventID = eventID
        self.eventTitle = eventTitle
        self.body = body
        self.deliveryDate = deliveryDate
        self.eventStartDate = eventStartDate
        self.isRead = false
        self.kind = kind
        self.senderName = senderName
    }
}
