//
//  SharedPushHandler.swift
//  Dozy AI
//
//  [Data Layer] 공유 캘린더 파트너 푸시 수신 처리 (#95, iOS).
//  - 받거나 탭한 푸시 → 앱 안 알림 카드(중복 없이) + 공유 일정 재동기화 + 위젯 갱신
//  - 앱이 꺼진 동안 받은 푸시는 Realtime 이 못 봤으므로, 앱이 활성화될 때 알림 센터에 남은 푸시에서 카드를 만든다
//    (Notification Service Extension 없이 처리)
//

import Foundation
import UserNotifications
import WidgetKit
import OSLog

@MainActor
final class SharedPushHandler {

    private let notificationRepository: NotificationRepository
    private let realtimeService: SharedCalendarRealtimeService

    init(notificationRepository: NotificationRepository, realtimeService: SharedCalendarRealtimeService) {
        self.notificationRepository = notificationRepository
        self.realtimeService = realtimeService
    }

    /// 수신(포그라운드) · 탭 때 AppDelegate 가 부른다. 공유 일정 푸시가 아니면 false.
    @discardableResult
    func handle(userInfo: [AnyHashable: Any]) -> Bool {
        guard let push = SharedEventPush(userInfo: userInfo) else { return false }
        record([push])
        realtimeService.resyncAllActive()
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    /// 앱 활성화 때 — 알림 센터에 남아 있는 공유 푸시를 카드로 옮긴다.
    func collectDelivered() async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let pushes = delivered.compactMap { SharedEventPush(userInfo: $0.request.content.userInfo) }
        guard !pushes.isEmpty else { return }
        if record(pushes) > 0 {
            realtimeService.resyncAllActive()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// - Returns: 새로 만든 카드 수
    @discardableResult
    private func record(_ pushes: [SharedEventPush]) -> Int {
        let created = pushes.filter { notificationRepository.saveSharedIfNeeded($0) }.count
        if created > 0 {
            NotificationCenter.default.post(name: .dozyNotificationsChanged, object: nil)
            Logger.push.info("공유 푸시 → 알림 카드 \(created)개")
        }
        return created
    }
}
