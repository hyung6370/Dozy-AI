//
//  MacAppDelegate.swift
//  Dozy AI (macOS)
//
//  저녁 요약 알림(#101)의 UNUserNotificationCenterDelegate.
//  - 앱이 떠 있어도 배너를 보여 주고
//  - 알림을 누르면 플래그를 켜고 `.dozyOpenDailySummary` 를 post 한다. MacAppCoordinator 가 오늘 섹션으로
//    옮기고 MacTodayView 가 플래그를 소비해 요약 시트를 연다 (아직 뷰가 없으면 onAppear 에서 소비).
//  앱이 꺼진 채 알림을 누르면 시스템이 앱을 실행하고 이 델리게이트를 부르므로 didFinishLaunching 에서 등록해야 한다.
//

import AppKit
import UserNotifications
import OSLog

extension Notification.Name {
    /// 요약 알림 탭 → 오늘 섹션 + 요약 시트. iOS 의 같은 이름과 역할이 같고 macOS 타깃에만 정의된다.
    static let dozyOpenDailySummary = Notification.Name("dozy.openDailySummary")
}

final class MacAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    /// 알림 탭을 아직 처리할 뷰가 없을 때(앱 실행 직후 · 다른 섹션) 들고 있는 플래그. MacTodayView 가 소비한다.
    static let pendingOpenSummaryKey = "pendingOpenDailySummary"

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 앱이 떠 있을 때도 배너를 보여 준다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// 알림 탭. 요약 알림이면 플래그 + post, 메인 창을 앞으로.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard SummaryReminderSchedule.isReminderIdentifier(response.notification.request.identifier) else { return }
        UserDefaults.standard.set(true, forKey: Self.pendingOpenSummaryKey)
        Logger.reminder.info("[요약 알림] 알림 탭 → 요약 열기 요청")
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            // 메인 창을 닫아 둔 상태면 다시 띄운다. WindowGroup(id: "main") 의 NSWindow identifier 는 "main-..." 으로 시작.
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) {
                window.makeKeyAndOrderFront(nil)
            }
            NotificationCenter.default.post(name: .dozyOpenDailySummary, object: nil)
        }
    }
}
