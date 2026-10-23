//
//  AppDelegate.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

/**
 SwiftUI App에 붙는 최소 AppDelegate
 - 앱 시작 직후에만 가능한 일: BGTaskScheduler 핸들러 등록. UNUserNotificaitonCenter delegate 지정
 - 요약 알림 탭 -> 플래그를 켜고 알림을 post. 플래그는 Dozy_AIApp이 active 전환 때 소비한다
    (콜드 스타트에 DependencyContainer가 아직 없어도 안전한 위젯/Siri와 같은 패턴)
 */

import UIKit
import UserNotifications
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    static let pendingOpenSummaryKey = "pendingOpenDailySummary"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SummaryReminderService.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            SummaryReminderService.handleBackgroundRefresh(refresh)
        }
        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// 앱이 떠 있을 때도 배너를 보여 준다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
    
    /// 알림 탭. 요약 알림이면 요약 시트를 열도록 플래그 + post.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == SummaryReminderService.notificationIdentifier else { return }
        UserDefaults.standard.set(true, forKey: Self.pendingOpenSummaryKey)
        NotificationCenter.default.post(name: .dozyOpenDailySummary, object: nil)
    }
}
