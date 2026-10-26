//
//  TodayAgendaActivityService.swift
//  Dozy AI
//
//  [Data Layer] ActivityKit 호출을 한 곳에 격리한다 — "오늘 아젠다" Live Activity 1개를 유지.
//
//  생명주기 (플랫폼 제약)
//  - 시작(Activity.request)은 앱이 포그라운드일 때만 가능. 백그라운드 자동 시작은 APNs push-to-start 전용(#95).
//  - 갱신(update)·종료(end)는 앱 프로세스가 돌 때(포그라운드·BGAppRefresh·LiveActivityIntent) 가능.
//  - 마지막 일정이면 end(dismissalPolicy: .after(종료 시각)) 로 마무리해 앱이 안 떠 있어도 종료 시각에 사라진다.
//    ended 상태에서도 timerInterval 뷰는 계속 움직이므로 진행 바·카운트다운은 그대로 보인다.
//  - staleDate 를 넘기면 시스템이 isStale 로 표시해 "앱을 열어 갱신" 안내를 띄울 수 있다.
//
//  하루 1개 원칙: 같은 dayKey 의 활성 액티비티가 있으면 재사용하고, 다른 날 것이나 중복은 즉시 내린다.
//

import Foundation
import OSLog

#if os(iOS)
import ActivityKit

@MainActor
final class TodayAgendaActivityService: LiveActivityServiceProtocol {

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - LiveActivityServiceProtocol

    func apply(_ plan: TodayAgendaPlan) async {
        switch plan {
        case .end:
            await endAll()
        case .show(let snapshot):
            await show(snapshot)
        }
    }

    func endAll() async {
        let live = Activity<TodayAgendaAttributes>.activities
        guard !live.isEmpty else { return }
        for activity in live {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        Logger.liveActivity.info("[아젠다] 액티비티 \(live.count)개 종료")
    }

    // MARK: - 표시

    private func show(_ snapshot: TodayAgendaSnapshot) async {
        let now = Date()
        let dayKey = Self.dayKey(for: now, calendar: calendar)
        let state = TodayAgendaAttributes.ContentState(snapshot)
        let content = ActivityContent(state: state, staleDate: snapshot.staleDate, relevanceScore: 100)

        // 오늘 것 하나만 남기고 정리. ended 상태(아직 화면에 남아 있는 것)는 재사용할 수 없으므로 함께 제외.
        let all = Activity<TodayAgendaAttributes>.activities
        var reusable: Activity<TodayAgendaAttributes>?
        for activity in all {
            let isLive = activity.activityState == .active || activity.activityState == .stale
            if isLive, activity.attributes.dayKey == dayKey, reusable == nil {
                reusable = activity
            } else if isLive {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        if let activity = reusable {
            if snapshot.isFinal, let dismissal = snapshot.dismissalDate {
                await activity.end(content, dismissalPolicy: .after(dismissal))
                Logger.liveActivity.info("[아젠다] 마지막 일정 — \(dismissal) 에 자동 종료 예약")
            } else {
                await activity.update(content)
                Logger.liveActivity.debug("[아젠다] 갱신 — current \(state.current?.title ?? "-", privacy: .public), next \(state.next?.title ?? "-", privacy: .public)")
            }
            return
        }

        // 새로 시작 — 포그라운드가 아니면 ActivityKit 이 throw 한다 (백그라운드 갱신 경로에서는 정상).
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Logger.liveActivity.info("[아젠다] Live Activity 가 시스템 설정에서 꺼져 있음")
            return
        }
        do {
            let activity = try Activity.request(
                attributes: TodayAgendaAttributes(dayKey: dayKey),
                content: content,
                pushType: nil
            )
            Logger.liveActivity.info("[아젠다] 시작 — id \(activity.id, privacy: .public), remaining \(state.remainingCount)")
            if snapshot.isFinal, let dismissal = snapshot.dismissalDate {
                await activity.end(content, dismissalPolicy: .after(dismissal))
            }
        } catch {
            Logger.liveActivity.error("[아젠다] 시작 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
#endif
