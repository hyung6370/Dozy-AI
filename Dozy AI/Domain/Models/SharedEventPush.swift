//
//  SharedEventPush.swift
//  Dozy AI
//
//  공유 캘린더 파트너 푸시 (#95). 서버 Edge Function `send-push` 가 보내는 payload 의 앱 쪽 해석.
//
//  {
//    "aps": { "alert": { "loc-key": "%@님이 '%@' 일정을 공유했습니다", "loc-args": [보낸 사람, 제목] }, "sound": "default" },
//    "dozy": { "type": "shared_event", "event_id": "...", "calendar_id": "...", "title": "...", "sender": "...", "start": "2026-10-29T09:00:00Z" }
//  }
//
//  배너 문구는 aps 의 loc-key 를 기기 언어로 iOS 가 직접 만들고, 앱 안 알림 카드는 아래 `cardBody` 로 같은 문구를 만든다.
//  프레임워크 의존 없음 — payload 해석 · 문구는 단위 테스트 대상.
//

import Foundation

nonisolated struct SharedEventPush: Equatable {

    static let type = "shared_event"

    let eventID: String
    let calendarID: String?
    let title: String
    let senderName: String?
    let startDate: Date?

    init(eventID: String, calendarID: String?, title: String, senderName: String?, startDate: Date?) {
        self.eventID = eventID
        self.calendarID = calendarID
        self.title = title
        self.senderName = senderName
        self.startDate = startDate
    }

    /// 공유 일정 푸시가 아니면 nil.
    init?(userInfo: [AnyHashable: Any]) {
        guard let dozy = userInfo["dozy"] as? [String: Any],
              dozy["type"] as? String == Self.type,
              let eventID = dozy["event_id"] as? String, !eventID.isEmpty,
              let title = dozy["title"] as? String else { return nil }
        let sender = (dozy["sender"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.init(
            eventID: eventID,
            calendarID: dozy["calendar_id"] as? String,
            title: title,
            senderName: sender,
            startDate: (dozy["start"] as? String).flatMap(Self.parseDate)
        )
    }

    var cardBody: String { SharedEventNotificationText.body(sender: senderName, title: title) }

    private static func parseDate(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}

/// 공유 일정 알림 문구 — Realtime 카드 · 푸시 카드 · 서버 loc-key 가 같은 문장을 쓴다.
nonisolated enum SharedEventNotificationText {
    /// 서버도 같은 두 키를 aps `loc-key` 로 보낸다 — 문구를 바꾸면 supabase/functions/send-push 도 함께 바꾼다.
    static let senderKey = "%@님이 '%@' 일정을 공유했습니다"
    static let partnerKey = "파트너님이 '%@' 일정을 공유했습니다"

    static func body(sender: String?, title: String) -> String {
        guard let name = sender.flatMap({ $0.isEmpty ? nil : $0 }) else {
            return String(localized: "파트너님이 '\(title)' 일정을 공유했습니다")
        }
        return String(localized: "\(name)님이 '\(title)' 일정을 공유했습니다")
    }
}

/// 푸시 관련 기기 설정 (#95). DependencyContainer 없이도 AppDelegate 가 읽고 쓴다.
nonisolated enum PushSettings {
    static let sharedNotificationsEnabledKey = "push.sharedNotificationsEnabled"
    static let deviceTokenKey = "push.deviceToken"

    /// 설정 "공유 캘린더 알림". 기본 켜짐.
    static func isSharedNotificationsEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: sharedNotificationsEnabledKey) == nil ? true : defaults.bool(forKey: sharedNotificationsEnabledKey)
    }

    static func setSharedNotificationsEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: sharedNotificationsEnabledKey)
    }

    static func deviceToken(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: deviceTokenKey)
    }

    static func setDeviceToken(_ token: String?, defaults: UserDefaults = .standard) {
        defaults.set(token, forKey: deviceTokenKey)
    }

    /// Debug 빌드는 development aps(sandbox), Release(TestFlight · App Store)는 production — 서버가 APNs 호스트를 고른다.
    static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// APNs 디바이스 토큰 Data → 서버가 쓰는 hex 문자열
    static func hexString(from token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }
}
