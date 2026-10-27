//
//  TodayAgendaActivityService.swift
//  Dozy AI
//
//  [Data Layer] ActivityKit 호출을 한 곳에 격리한다 — "오늘 아젠다" Live Activity 1개를 유지.
//
//  생명주기 (플랫폼 제약)
//  - 시작(Activity.request)은 앱이 포그라운드일 때만 한다. LiveActivityIntent(위젯 체크박스·잠금화면 완료 버튼)가
//    앱을 백그라운드로 깨웠을 때도 ActivityKit 은 시작을 허용하지만, 그렇게 만들어진 액티비티에는 iOS 가
//    "실시간 현황을 허용하겠습니까?" 승인 프롬프트를 붙인다(포그라운드 시작에는 안 붙음). 사용자가 "허용 안 함" 을
//    누르면 앱의 Live Activity 가 통째로 꺼지므로 백그라운드에서는 갱신·종료만 하고 시작은 다음 포그라운드로 미룬다.
//    백그라운드 자동 시작은 APNs push-to-start 전용(#95).
//  - 갱신(update)·종료(end)는 앱 프로세스가 돌 때(포그라운드·BGAppRefresh·LiveActivityIntent) 가능.
//  - 마지막 일정이면 end(dismissalPolicy: .after(종료 시각)) 로 마무리해 앱이 안 떠 있어도 종료 시각에 사라진다.
//    ended 상태에서도 timerInterval 뷰는 계속 움직이므로 진행 바·카운트다운은 그대로 보인다.
//  - staleDate 를 넘기면 시스템이 isStale 로 표시해 "앱을 열어 갱신" 안내를 띄울 수 있다.
//
//  하루 1개 원칙: 같은 dayKey 의 활성 액티비티가 있으면 재사용하고, 다른 날 것이나 중복은 즉시 내린다.
//  예약 종료(ended) 상태는 update 가 안 되므로 내용이 같으면 그대로 두고, 다르면 새로 띄운 뒤(성공했을 때만) 내린다.
//

import Foundation
import OSLog

#if os(iOS)
import ActivityKit
import UIKit

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

        // 오늘 것 하나만 남기고 정리.
        // - live(active·stale): 첫 번째를 재사용, 나머지는 중복이므로 즉시 내린다.
        // - ended(예약 종료 대기 중, 아직 화면에 남아 있음): update 가 안 되므로 재사용할 수 없다.
        //   내용이 지금 계획과 같으면 그대로 두고(이미 종료 시각에 사라지도록 예약됨), 다르면 즉시 내리고 새로 띄운다.
        //   내리지 않으면 매 갱신마다 새 액티비티가 쌓여 잠금화면에 중복으로 보인다.
        // - 다른 날 것은 상태와 무관하게 즉시 내린다.
        let all = Activity<TodayAgendaAttributes>.activities
        var reusable: Activity<TodayAgendaAttributes>?
        var endedToday: [Activity<TodayAgendaAttributes>] = []
        for activity in all {
            let isLive = activity.activityState == .active || activity.activityState == .stale
            let isToday = activity.attributes.dayKey == dayKey
            if isLive, isToday, reusable == nil {
                reusable = activity
            } else if isLive || !isToday {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else if activity.activityState == .ended {
                endedToday.append(activity)
            }
        }

        if let activity = reusable {
            for ended in endedToday { await ended.end(nil, dismissalPolicy: .immediate) }
            if snapshot.isFinal, let dismissal = snapshot.dismissalDate {
                await activity.end(content, dismissalPolicy: .after(dismissal))
                Logger.liveActivity.info("[아젠다] 마지막 일정 — \(dismissal) 에 자동 종료 예약")
            } else {
                await activity.update(content)
                Logger.liveActivity.debug("[아젠다] 갱신 — current \(state.current?.title ?? "-", privacy: .public), next \(state.next?.title ?? "-", privacy: .public)")
            }
            return
        }

        // 예약 종료된 것이 지금 계획과 같은 내용이면 그대로 둔다 (같은 종료 시각에 사라진다).
        if snapshot.isFinal, let same = endedToday.first(where: { $0.content.state == state }) {
            for ended in endedToday where ended.id != same.id { await ended.end(nil, dismissalPolicy: .immediate) }
            Logger.liveActivity.debug("[아젠다] 예약 종료 상태 유지 — id \(same.id, privacy: .public)")
            return
        }

        // 새로 시작 — 포그라운드에서만. 백그라운드(LiveActivityIntent·BGAppRefresh)에서 시작하면 iOS 가 카드에
        // 승인 프롬프트를 붙이므로 다음 포그라운드 동기화로 미룬다. 내용이 달라진 ended 는 새 액티비티가 떴을 때만
        // 내린다 — 시작을 건너뛰면 옛 카드라도 남겨 두는 편이 낫다.
        guard UIApplication.shared.applicationState != .background else {
            Logger.liveActivity.info("[아젠다] 백그라운드라 시작 보류 — 다음 포그라운드에서 띄움")
            return
        }
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
            for ended in endedToday { await ended.end(nil, dismissalPolicy: .immediate) }
            if snapshot.isFinal, let dismissal = snapshot.dismissalDate {
                await activity.end(content, dismissalPolicy: .after(dismissal))
                Logger.liveActivity.info("[아젠다] 마지막 일정 — \(dismissal) 에 자동 종료 예약")
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
