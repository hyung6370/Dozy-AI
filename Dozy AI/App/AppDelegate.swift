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
 - APNs (#95): 원격 알림 등록 · 토큰 수신 · 공유 캘린더 푸시 수신/탭. 컨테이너 쪽 처리는 PushHooks 로 넘긴다
 */

import UIKit
import UserNotifications
import BackgroundTasks
import SwiftData
import OSLog

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    static let pendingOpenSummaryKey = "pendingOpenDailySummary"
    /// 공유 푸시 탭 → 알림 목록을 연다 (요약 알림과 같은 플래그 패턴)
    static let pendingOpenNotificationsKey = "pendingOpenNotifications"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SummaryReminderService.backgroundTaskIdentifier,
            using: nil
        ) { @Sendable task in
            // 백그라운드 큐에서 불린다 (queue nil). @Sendable 로 메인 액터 추론을 끊어 Swift 6 런타임 격리 검사를 피한다.
            // 안에서 부르는 handleBackgroundRefresh 는 nonisolated 이고 필요한 일은 스스로 메인 액터로 넘긴다.
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            SummaryReminderService.handleBackgroundRefresh(refresh)
        }

        // Live Activity 의 완료 버튼(LiveActivityIntent)이 앱을 백그라운드로 띄우면 DependencyContainer 가
        // 아직 없을 수 있다 (DEBUG 는 환경 선택 전). App Group store 를 직접 여는 독립 실행 훅을 먼저 꽂아 두고,
        // AppCoordinator.setup() 이 컨테이너 유스케이스로 덮어쓴다.
        if TodayAgendaLiveActivityHooks.refresh == nil {
            TodayAgendaLiveActivityHooks.refresh = { _ = await Self.standaloneLiveActivitySync()?.execute() }
        }

        // APNs 토큰 요청 (#95). 알림 권한과 별개로 토큰은 발급되고, 표시 여부만 권한을 따른다.
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - APNs (#95)

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = PushSettings.hexString(from: deviceToken)
        // 컨테이너가 아직 없어도(DEBUG 환경 선택 전) 기기에 남겨 두면 로그인 · 연결 시점에 올라간다
        PushSettings.setDeviceToken(token)
        Logger.push.info("APNs 토큰 수신")
        Task { @MainActor in PushHooks.tokenReceived?() }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.push.error("APNs 등록 실패: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Live Activity (독립 실행)

    private static let appGroupID = "group.com.dozy-ai.shared"

    /// 위젯(TodayEventsDataSource)과 같은 방식으로 App Group store 를 열어 캐시만 읽는 유스케이스.
    @MainActor
    private static func standaloneLiveActivitySync() -> SyncTodayLiveActivityUseCase? {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("default.store") else { return nil }
        // 앱과 같은 전체 스키마 — 부분 스키마로 열면 WorkLog 등 테이블이 지워진다 (DozySchema 참고).
        let schema = DozySchema.schema
        let config = ModelConfiguration(schema: schema, url: storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else { return nil }
        return SyncTodayLiveActivityUseCase(
            service: TodayAgendaActivityService(),
            loadItems: { TodayEventCacheWriter.loadTodayAgendaItems(container: container) }
        )
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// 앱이 떠 있을 때도 배너를 보여 준다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 공유 일정 푸시면 앱 안 알림 카드 · 동기화도 바로 (Realtime 이 같은 일정을 보면 카드는 중복 없이 하나)
        let userInfo = notification.request.content.userInfo
        await MainActor.run { PushHooks.deliver(userInfo) }
        return [.banner, .sound]
    }
    
    /// 알림 탭. 요약 알림이면 요약 시트를 열도록 플래그 + post.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        // 공유 일정 푸시 탭 — 카드 · 동기화 후 알림 목록을 연다. 탭한 알림은 알림 센터에서 사라지므로 여기서 꼭 처리한다.
        if SharedEventPush(userInfo: userInfo) != nil {
            await MainActor.run { PushHooks.deliver(userInfo) }
            UserDefaults.standard.set(true, forKey: Self.pendingOpenNotificationsKey)
            NotificationCenter.default.post(name: .dozyOpenNotifications, object: nil)
            return
        }
        guard SummaryReminderSchedule.isReminderIdentifier(response.notification.request.identifier) else { return }
        UserDefaults.standard.set(true, forKey: Self.pendingOpenSummaryKey)
        NotificationCenter.default.post(name: .dozyOpenDailySummary, object: nil)
    }
}

// MARK: - Push Hooks (#95)

/// AppDelegate 콜백 → 살아있는 DependencyContainer. AppCoordinator.setup() 이 꽂는다.
/// 콜드 스타트에 컨테이너보다 푸시가 먼저 오면 쌓아 두었다가 연결될 때 처리한다.
@MainActor
enum PushHooks {
    /// 새 토큰 → 로그인 상태면 서버 등록
    static var tokenReceived: (() -> Void)?
    /// 공유 일정 푸시 처리. 연결 전이면 nil.
    static var sharedPushReceived: (([AnyHashable: Any]) -> Void)? {
        didSet { flushPending() }
    }
    private static var pending: [[AnyHashable: Any]] = []

    static func deliver(_ userInfo: [AnyHashable: Any]) {
        guard SharedEventPush(userInfo: userInfo) != nil else { return }
        if let handler = sharedPushReceived {
            handler(userInfo)
        } else {
            pending.append(userInfo)
        }
    }

    private static func flushPending() {
        guard let handler = sharedPushReceived, !pending.isEmpty else { return }
        let items = pending
        pending.removeAll()
        items.forEach(handler)
    }
}
