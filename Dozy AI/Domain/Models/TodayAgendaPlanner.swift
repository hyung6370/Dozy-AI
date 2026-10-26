//
//  TodayAgendaPlanner.swift
//  Dozy AI
//
//  [Domain] "오늘 아젠다" Live Activity 의 순수 계산 부분.
//  ActivityKit 에 의존하지 않는 값 타입과 계획 함수만 둬서 macOS 타깃·위젯 extension·단위 테스트에서
//  그대로 컴파일된다. 실제 Activity 시작/갱신/종료는 Data 레이어(TodayAgendaActivityService)가 맡는다.
//
//  규칙
//  - 시간제 일정만 대상 (종일 일정은 카운트다운·진행 바 의미가 없음)
//  - 완료된 일정은 "지나간 것" 으로 취급 — current/next 후보에서 빠지고 completedCount 에만 반영
//  - current: 지금 진행 중인 가장 이른 일정, next: 아직 시작 전인 가장 이른 일정
//  - 둘 다 없으면 .end (오늘 남은 시간제 일정 없음 → 액티비티 내린다)
//  - staleDate: 화면이 낡는 시각 = current 종료 또는 next 시작 중 먼저 오는 것.
//    앱이 그 시각에 떠 있지 않으면 시스템이 isStale 로 흐리게 표시만 해 준다.
//  - 마지막 일정이 진행 중이고 종료가 4시간 안이면 isFinal — 서비스가 end(dismissalPolicy: .after(종료)) 로
//    앱이 안 떠 있어도 종료 시각에 자동으로 사라지게 한다 (ActivityKit 의 예약 종료 상한이 4시간).
//

import Foundation

/// 위젯 캐시(TodayEventCache) 한 줄을 플래너 입력으로 옮긴 값.
struct TodayAgendaItem: Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let isCompleted: Bool
    let colorHex: String

    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool, isCompleted: Bool, colorHex: String) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.isCompleted = isCompleted
        self.colorHex = colorHex
    }
}

/// Live Activity 에 표시할 일정 1건. ContentState 로 그대로 옮겨진다.
struct TodayAgendaEntry: Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let colorHex: String
}

/// 액티비티에 표시할 스냅샷. ContentState + 갱신 메타데이터.
struct TodayAgendaSnapshot: Equatable, Sendable {
    let current: TodayAgendaEntry?
    let next: TodayAgendaEntry?
    /// 아직 끝나지 않은 시간제 일정 수 (진행 중 포함, 완료 제외).
    let remainingCount: Int
    /// 오늘 시간제 일정 중 완료된 수.
    let completedCount: Int
    /// 오늘 시간제 일정 총 수.
    let totalCount: Int
    /// 이 화면이 낡는 시각. nil 이면 더 바뀔 일이 없음.
    let staleDate: Date?
    /// true 면 이게 마지막 일정 — 서비스가 종료 시각에 자동 제거되도록 end(.after) 로 마무리한다.
    let isFinal: Bool
    /// isFinal 일 때 액티비티를 치울 시각 (current.end).
    let dismissalDate: Date?
}

enum TodayAgendaPlan: Equatable, Sendable {
    /// 오늘 남은 시간제 일정이 없다 → 떠 있는 액티비티를 즉시 내린다.
    case end
    /// 표시할 내용이 있다.
    case show(TodayAgendaSnapshot)
}

enum TodayAgendaPlanner {

    /// ActivityKit 이 예약 종료(dismissalPolicy .after)에 허용하는 최대 지연.
    static let maxScheduledDismissal: TimeInterval = 4 * 60 * 60

    static func plan(items: [TodayAgendaItem], now: Date = Date()) -> TodayAgendaPlan {
        let timed = items
            .filter { !$0.isAllDay && $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard !timed.isEmpty else { return .end }

        let active = timed.filter { !$0.isCompleted }
        let current = active.first { $0.start <= now && now < $0.end }
        let next = active.first { $0.start > now }

        guard current != nil || next != nil else { return .end }

        let remaining = active.filter { $0.end > now }.count
        let completed = timed.filter(\.isCompleted).count

        let staleCandidates = [current?.end, next?.start].compactMap { $0 }
        let staleDate = staleCandidates.min()

        let isFinal: Bool
        let dismissalDate: Date?
        if let current, next == nil, current.end.timeIntervalSince(now) <= maxScheduledDismissal {
            isFinal = true
            dismissalDate = current.end
        } else {
            isFinal = false
            dismissalDate = nil
        }

        return .show(TodayAgendaSnapshot(
            current: current.map(entry),
            next: next.map(entry),
            remainingCount: remaining,
            completedCount: completed,
            totalCount: timed.count,
            staleDate: staleDate,
            isFinal: isFinal,
            dismissalDate: dismissalDate
        ))
    }

    private static func entry(_ item: TodayAgendaItem) -> TodayAgendaEntry {
        TodayAgendaEntry(id: item.id, title: item.title, start: item.start, end: item.end, colorHex: item.colorHex)
    }
}

// MARK: - 설정

/// 잠금화면 "오늘 일정" Live Activity 켬/끔. UserDefaults 저장, 기본 켬.
enum LiveActivitySettings {
    static let isEnabledKey = "liveActivity.isEnabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: isEnabledKey) != nil else { return true }
        return defaults.bool(forKey: isEnabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: isEnabledKey)
    }
}

// MARK: - 캐시 변경 훅

/// 위젯 캐시(TodayEventCache)가 바뀔 때 Live Activity 를 다시 맞추기 위한 연결 고리.
/// TodayEventCacheWriter 는 앱·위젯 양쪽에 컴파일되므로 ActivityKit 을 직접 부를 수 없다.
/// iOS 앱이 시작할 때 refresh 를 꽂아 두면 Writer 가 저장 직후 호출한다 (위젯 extension 에서는 nil).
enum TodayAgendaLiveActivityHooks {
    nonisolated(unsafe) static var refresh: (@MainActor () async -> Void)?

    /// 캐시 저장 직후 호출. 훅이 없으면 아무것도 하지 않는다.
    @MainActor
    static func cacheDidChange() {
        guard let refresh else { return }
        Task { @MainActor in await refresh() }
    }
}
