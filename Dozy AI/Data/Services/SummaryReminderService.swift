//
//  SummaryReminderService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/23/26.
//

/**
[Data Layer] 저녁 요약 알림 스케줄 + 백그라운드 미리 생성
 - 알림: 향후 7일치 날짜별 단발 UNCalendarNotificationTrigger (SummaryReminderSchedule). 반복 1개가 아니라 날짜별로 쪼갠 이유:
    · 오늘 요약을 앱에서 이미 봤으면 오늘 요청만 지워 발송을 생략할 수 있다
    · 백그라운드 생성이 끝나면 오늘 요청 본문만 "N건 완료 · 생산성 N점"으로 바꿀 수 있다 (안 돈 날은 고정 문구 그대로)
   앱 시작·포그라운드 복귀·백그라운드 갱신 때마다 7일치를 다시 채운다.
 - 백그라운드: BGAppRefreshTask를 알림 1시간 전으로 요청. 실행되면 backgroundSummaryProvider로 요약을 만들어
    WorkLog에 저장해 두고(탭하면 즉시 열림), 오늘 알림 본문을 수치로 바꾸고, 다음 날 분을 재예약한다. 등록 자체는 AppDelegate가 한다.
 */

// macOS 타깃에도 포함되지만 BackgroundTasks 가 macOS 에 없으므로 iOS 에서만 컴파일한다.
#if os(iOS)
import Foundation
import UserNotifications
import BackgroundTasks
import OSLog

/// 백그라운드에서 만든 요약과, 알림 본문에 쓰는 오늘 완료 일정 수.
struct BackgroundSummaryResult {
    let summary: DailySummary
    let completedEventCount: Int
}

@MainActor
final class SummaryReminderService {

    static let notificationCategory = "DOZY_SUMMARY_REMINDER"
    static let backgroundTaskIdentifier = "com.dozy-ai.Dozy-AI.summaryRefresh"

    /// 백그라운드 갱신 때 요약을 만들어 줄 공급자. AppCoordinator.setup()이 컨테이너로 연결한다.
    /// nil(DEBUG 환경 선택 전 등)이면 생성은 건너뛰고 재예약만 한다.
    nonisolated(unsafe) static var backgroundSummaryProvider: (() async throws -> BackgroundSummaryResult)?

    private let center = UNUserNotificationCenter.current()

    // MARK: - 설정 반영

    /// 설정을 스케줄에 반영한다. 켤 때 알림 권한이 거부돼 있으면 false를 돌려주고 아무것도 예약하지 않는다.
    @discardableResult
    func apply(_ settings: SummaryReminderSettings) async -> Bool {
        guard settings.isEnabled else {
            await Self.cancelAll()
            Logger.reminder.info("[요약 알림] 해제")
            return true
        }
        guard await requestAuthorizationIfNeeded() else {
            await Self.cancelAll()
            Logger.reminder.error("[요약 알림] 알림 권한 없음 → 예약 취소")
            return false
        }
        await Self.rescheduleAll(settings)
        Self.scheduleBackgroundRefresh(settings)
        Logger.reminder.info("[요약 알림] 매일 \(settings.hour):\(String(format: "%02d", settings.minute)) 예약")
        return true
    }

    /// 앱 시작, 포그라운드 복귀 때 - 켜져 있으면 7일치를 다시 채우고 백그라운드 갱신을 재제출한다.
    func refreshSchedulesIfEnabled() {
        let settings = SummaryReminderSettings.load()
        guard settings.isEnabled else { return }
        Task { await Self.topUpUpcoming(settings) }
        Self.scheduleBackgroundRefresh(settings)
    }

    /// 요약 화면을 열었을 때 호출. 오늘 요약을 이미 봤으니 오늘 알림은 지운다 (내일 이후는 그대로).
    func markSummaryViewed(now: Date = Date()) {
        SummaryReminderViewedStore.markViewed(on: now)
        let todayID = SummaryReminderSchedule.identifier(forDayKey: SummaryReminderSchedule.dayKey(for: now))
        center.removePendingNotificationRequests(withIdentifiers: [todayID])
        Logger.reminder.info("[요약 알림] 오늘 요약 확인 → 오늘 알림 생략")
    }

    // MARK: - 권한

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

    // MARK: - 알림 요청 관리

    /// 대기 중인 요약 알림 식별자 전부 (예전 반복 요청 포함).
    private static func pendingReminderIdentifiers() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(requests.map(\.identifier).filter(SummaryReminderSchedule.isReminderIdentifier))
    }

    /// 요약 알림 요청과 백그라운드 갱신을 모두 취소한다.
    static func cancelAll() async {
        let ids = await pendingReminderIdentifiers()
        if !ids.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(ids))
        }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
    }

    /// 시각이 바뀌었을 때 - 기존 요청을 전부 지우고 새 시각으로 7일치를 다시 만든다.
    static func rescheduleAll(_ settings: SummaryReminderSettings, now: Date = Date()) async {
        let ids = await pendingReminderIdentifiers()
        if !ids.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(ids))
        }
        await topUpUpcoming(settings, now: now)
    }

    /// 7일치 중 빠진 날만 고정 문구로 추가하고, 더 이상 유효하지 않은 요청(예전 반복 요청, 지난 날, 오늘 이미 본 날)은 정리한다.
    /// 이미 있는 요청은 건드리지 않으므로 백그라운드가 바꿔 둔 오늘 수치 본문이 유지된다.
    static func topUpUpcoming(_ settings: SummaryReminderSettings, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let slots = SummaryReminderSchedule.desiredSlots(
            settings: settings,
            from: now,
            viewedToday: SummaryReminderViewedStore.hasViewed(on: now)
        )
        let plan = SummaryReminderSchedule.plan(desired: slots, pending: await pendingReminderIdentifiers())

        if !plan.remove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: plan.remove)
        }

        var added = 0
        for slot in plan.add {
            let content = makeContent(
                body: String(localized: "Dozy가 오늘 일정과 할 일을 요약해 드릴게요. 눌러서 확인해 보세요."),
                dayKey: slot.dayKey
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: slot.components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: slot.identifier, content: content, trigger: trigger))
                added += 1
            } catch {
                Logger.reminder.error("[요약 알림] 예약 실패 \(slot.dayKey): \(error.localizedDescription, privacy: .public)")
            }
        }
        Logger.reminder.info("[요약 알림] \(slots.count)일치 유지 — 추가 \(added), 정리 \(plan.remove.count)")
    }

    /// 백그라운드 생성 결과를 오늘 알림 본문에 반영한다.
    /// 오늘 시각이 이미 지났거나 오늘 요약을 이미 봤으면 바꿀 알림이 없으므로 아무것도 하지 않는다.
    static func applyBackgroundResult(
        _ result: BackgroundSummaryResult,
        settings: SummaryReminderSettings,
        now: Date = Date()
    ) async {
        guard settings.isEnabled, !SummaryReminderViewedStore.hasViewed(on: now) else { return }
        guard let slot = SummaryReminderSchedule.upcomingSlots(settings: settings, from: now, days: 1).first else { return }

        let content = makeContent(
            body: SummaryReminderSchedule.numericBody(
                completedEventCount: result.completedEventCount,
                productivityScore: result.summary.productivityScore
            ),
            dayKey: slot.dayKey
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: slot.components, repeats: false)
        do {
            // 같은 식별자로 add 하면 기존 요청이 교체된다.
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: slot.identifier, content: content, trigger: trigger)
            )
            Logger.reminder.info("[요약 알림] 오늘 본문을 수치로 교체 — \(result.completedEventCount)건, score \(result.summary.productivityScore)")
        } catch {
            Logger.reminder.error("[요약 알림] 오늘 본문 교체 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func makeContent(body: String, dayKey: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "오늘 하루를 정리할 시간이에요")
        content.body = body
        content.sound = .default
        content.categoryIdentifier = notificationCategory
        content.userInfo = [SummaryReminderSchedule.userInfoDayKey: dayKey]
        return content
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

    /// AppDelegate의 등록 핸들러가 부른다. 다음 날 분을 먼저 재예약하고, 7일치를 채운 뒤, 요약을 만들어 저장하고 오늘 본문을 바꾼다.
    nonisolated static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        let settings = SummaryReminderSettings.load()
        if settings.isEnabled { scheduleBackgroundRefresh(settings) }

        let work = Task { @MainActor in
            guard settings.isEnabled else {
                task.setTaskCompleted(success: true)
                return
            }
            await topUpUpcoming(settings)
            guard let provider = backgroundSummaryProvider else {
                task.setTaskCompleted(success: true)
                return
            }
            do {
                let result = try await provider()
                Logger.reminder.info("[요약 알림] 백그라운드 요약 생성 완료 — score \(result.summary.productivityScore)")
                await applyBackgroundResult(result, settings: settings)
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
