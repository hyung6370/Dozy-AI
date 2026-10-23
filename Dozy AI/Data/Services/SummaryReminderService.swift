//
//  SummaryReminderService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/23/26.
//

/**
[Data Layer] 저녁 요약 알림 스케줄 + 백그라운드 미리 생성
 - 알림: 매일 반복 UNCalendarNotificationTrigger 하나. 본문은 고정 문구 (백그라운드 결과를 본문에 넣지 않는다 -
    백그라운드가 안 돈 날 전날 문구가 노출되는 것을 피하기 위해)
 - 백그라운드: BGAppRefreshTask를 알림 1시간 전으로 요청. 실행되면 backgroundSummaryProvider로 요약을 만들어
    WorkLog에 저장해 두고(탭하면 즉시 열림), 다음 날 분을 재예약한다. 등록 자체는 AppDelegate가 한다.
 */

// macOS 타깃에도 포함되지만 BackgroundTasks 가 macOS 에 없으므로 iOS 에서만 컴파일한다.
#if os(iOS)
import Foundation
import UserNotifications
import BackgroundTasks
import OSLog

@MainActor
final class SummaryReminderService {
    
    static let notificationIdentifier = "dozy.summaryReminder"
    static let notificationCategory = "DOZY_SUMMARY_REMINDER"
    static let backgroundTaskIdentifier = "com.dozy-ai.Dozy-AI.summaryRefresh"
    
    /// 백그라운드 갱신 때 요약을 만들어 줄 공급자. AppCoordinator.setup()이 컨테이너로 연결한다.
    /// nil(DEBUG 환경 선ㅌ개 전 등)이면 생성은 건너뛰고 재예약만 한다.
    nonisolated(unsafe) static var backgroundSummaryProvider: (() async throws -> DailySummary)?
    
    private let center = UNUserNotificationCenter.current()
    
    // MARK: - 설정 반영
    
    /// 설정을 스케줄에 반영한다. 켤 때 알림 권한이 거부돼 있으면 false를 돌려주고 아무것도 예약하지 않는다
    @discardableResult
    func apply(_ settings: SummaryReminderSettings) async -> Bool {
        guard settings.isEnabled else {
            cancelAll()
            Logger.reminder.info("[요약 알림] 해제")
            return true
        }
        guard await requestAuthorizationIfNeeded() else {
            cancelAll()
            Logger.reminder.error("[요약 알림] 알림 권한 없음 → 예약 취소")
            return false
        }
        scheduleNotification(settings)
        Self.scheduleBackgroundRefresh(settings)
        Logger.reminder.info("[요약 알림] 매일 \(settings.hour):\(String(format: "%02d", settings.minute)) 예약")
        return true
    }
    
    /// 앱 시작, 포그라운드 복귀 때 - 켜져 있으면 백그라운드 갱신만 다시 제출(알림은 반복 트리거라 그대로)
    func refreshSchedulesIfEnabled() {
        let settings = SummaryReminderSettings.load()
        guard settings.isEnabled else { return }
        Self.scheduleBackgroundRefresh(settings)
    }
    
    // MARK: - 알림
    
    private func requestAuthorizationIfNeeded() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }
    
    private func scheduleNotification(_ settings: SummaryReminderSettings) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "오늘 하루를 정리할 시간이에요")
        content.body = String(localized: "Dozy가 오늘 일정과 할 일을 요약해 드릴게요. 눌러서 확인해 보세요.")
        content.sound = .default
        content.categoryIdentifier = Self.notificationCategory
        
        var components = DateComponents()
        components.hour = settings.hour
        components.minute = settings.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.add(UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger))
    }
    
    private func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)
    }
    
    // MARK: - 백그라운드 갱신
    
    /// 알림 1시간 전을 earliestBeginDate로 제출. 실제 실행 시점은 iOS 재량
    nonisolated static func scheduleBackgroundRefresh(_ settings: SummaryReminderSettings) {
        guard let fireDate = settings.nextFireDate() else { return }
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = fireDate.addingTimeInterval(-60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.reminder.info("[요약 알림] 백그라운드 갱신 제출 — earliest \(request.earliestBeginDate!)")
        } catch {
            // 시뮬레이터, 저전력 등에서는 거부될 수 있다. 알림은 그대로 가므로 치명적이지 않다
            Logger.reminder.error("[요약 알림] 백그라운드 갱신 제출 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// AppDelegate의 등록 핸들러가 부른다. 다음 날 분을 먼저 재예약하고, 요약을 만들어 저장한다.
    nonisolated static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        let settings = SummaryReminderSettings.load()
        if settings.isEnabled { scheduleBackgroundRefresh(settings) }
        
        let work = Task { @MainActor in
            guard settings.isEnabled, let provider = backgroundSummaryProvider else {
                task.setTaskCompleted(success: true)
                return
            }
            do {
                let summary = try await provider()
                Logger.reminder.info("[요약 알림] 백그라운드 요약 생성 완료 — score \(summary.productivityScore)")
                task.setTaskCompleted(success: true)
            } catch {
                Logger.reminder.error("[요약 알림] 백그라운드 요약 실패: \(error.localizedDescription, privacy: .public)")
                task.setTaskCompleted(success: false)
            }
        }
        // 시간 초과(약 30초) 시 iOS 가 호출 — 작업을 끊고 실패로 마감. 다음 날 다시 시도된다.
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
#endif
