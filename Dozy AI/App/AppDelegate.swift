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
import SwiftData

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

        // Live Activity 의 완료 버튼(LiveActivityIntent)이 앱을 백그라운드로 띄우면 DependencyContainer 가
        // 아직 없을 수 있다 (DEBUG 는 환경 선택 전). App Group store 를 직접 여는 독립 실행 훅을 먼저 꽂아 두고,
        // AppCoordinator.setup() 이 컨테이너 유스케이스로 덮어쓴다.
        if TodayAgendaLiveActivityHooks.refresh == nil {
            TodayAgendaLiveActivityHooks.refresh = { _ = await Self.standaloneLiveActivitySync()?.execute() }
        }
        return true
    }

    // MARK: - Live Activity (독립 실행)

    private static let appGroupID = "group.com.dozy-ai.shared"

    /// 위젯(TodayEventsDataSource)과 같은 방식으로 App Group store 를 열어 캐시만 읽는 유스케이스.
    @MainActor
    private static func standaloneLiveActivitySync() -> SyncTodayLiveActivityUseCase? {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("default.store") else { return nil }
        let schema = Schema([TodayEventCache.self, DozyEvent.self, EventCompletion.self, UserCategory.self])
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
        [.banner, .sound]
    }
    
    /// 알림 탭. 요약 알림이면 요약 시트를 열도록 플래그 + post.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard SummaryReminderSchedule.isReminderIdentifier(response.notification.request.identifier) else { return }
        UserDefaults.standard.set(true, forKey: Self.pendingOpenSummaryKey)
        NotificationCenter.default.post(name: .dozyOpenDailySummary, object: nil)
    }
}
