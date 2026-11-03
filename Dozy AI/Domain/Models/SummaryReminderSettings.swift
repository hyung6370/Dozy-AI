//
//  SummaryReminderSettings.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/23/26.
//

// 저녁 요약 알림 설정 값 타입. UserDefaults에 저장하고 설정 화면/스케줄러가 공유한다.

import Foundation

// 순수 값 타입 — BGTask 핸들러(nonisolated)에서 load · nextFireDate 를 부른다.
nonisolated struct SummaryReminderSettings: Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    
    static let `default` = SummaryReminderSettings(isEnabled: false, hour: 21, minute: 0)
    
    private enum Keys {
        static let isEnabled = "summaryReminder.isEnabled"
        static let hour = "summaryReminder.hour"
        static let minute = "summaryReminder.minute"
    }
    
    static func load(from defaults: UserDefaults = .standard) -> SummaryReminderSettings {
        guard defaults.object(forKey: Keys.hour) != nil else { return .default }
        return SummaryReminderSettings(
            isEnabled: defaults.bool(forKey: Keys.isEnabled),
            hour: defaults.integer(forKey: Keys.hour),
            minute: defaults.integer(forKey: Keys.minute)
        )
    }
    
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(hour, forKey: Keys.hour)
        defaults.set(minute, forKey: Keys.minute)
    }
    
    /// 다음 알림 시각 - 오늘 그 시각이 아직 안 지났으면 오늘, 지났으면 내일
    func nextFireDate(after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let today = calendar.date(from: components) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }
    
    /// 시각 선택기(DatePicker) 바인딩용 - 오늘 날짜에 hour:minute를 얹은 Date
    var timeAsDate: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - 날짜별 단발 알림 스케줄 (순수 계산)

/// 저녁 요약 알림은 "매일 반복 1개"가 아니라 "향후 N일치 단발 요청"으로 예약한다.
/// 요청이 날짜별 식별자를 가지므로 오늘 것만 지우거나(요약 확인 시 발송 생략), 오늘 본문만 바꿀 수(백그라운드 수치 반영) 있다.
/// UserNotifications 에 의존하지 않는 계산만 둬서 macOS 타깃과 단위 테스트에서도 그대로 컴파일된다.
enum SummaryReminderSchedule {

    /// 모든 요약 알림 요청 식별자의 접두사. 예전 반복 요청의 식별자("dozy.summaryReminder")와 같아
    /// 접두사 매칭으로 정리하면 업그레이드한 기기의 반복 요청도 함께 제거된다.
    static let identifierPrefix = "dozy.summaryReminder"
    /// 미리 예약해 두는 일수. 앱 시작·복귀·백그라운드 갱신 때마다 이 일수만큼 채운다.
    static let rollingDays = 7
    /// userInfo 에 담는 날짜 키(yyyy-MM-dd). 알림 탭 시 어느 날 요약인지 식별하는 용도.
    static let userInfoDayKey = "summaryDay"

    struct Slot: Equatable {
        let dayKey: String
        let identifier: String
        let fireDate: Date
        let components: DateComponents
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func identifier(forDayKey dayKey: String) -> String {
        "\(identifierPrefix).\(dayKey)"
    }

    static func isReminderIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }

    /// 지금 이후에 울릴 슬롯만 오늘부터 `days`일치 돌려준다. 오늘 시각이 이미 지났으면 오늘은 빠진다.
    static func upcomingSlots(
        settings: SummaryReminderSettings,
        from now: Date = Date(),
        days: Int = rollingDays,
        calendar: Calendar = .current
    ) -> [Slot] {
        let startOfToday = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fire = calendar.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: day),
                  fire > now else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = settings.hour
            components.minute = settings.minute
            let key = dayKey(for: day, calendar: calendar)
            return Slot(dayKey: key, identifier: identifier(forDayKey: key), fireDate: fire, components: components)
        }
    }

    /// 실제로 예약돼 있어야 하는 슬롯. 오늘 요약을 이미 봤으면 오늘 슬롯은 뺀다.
    static func desiredSlots(
        settings: SummaryReminderSettings,
        from now: Date = Date(),
        viewedToday: Bool,
        days: Int = rollingDays,
        calendar: Calendar = .current
    ) -> [Slot] {
        var slots = upcomingSlots(settings: settings, from: now, days: days, calendar: calendar)
        if viewedToday {
            let todayKey = dayKey(for: now, calendar: calendar)
            slots.removeAll { $0.dayKey == todayKey }
        }
        return slots
    }

    /// 대기 중인 요청과 비교해 추가할 슬롯과 지울 식별자를 계산한다.
    /// 이미 있는 요청은 건드리지 않아 백그라운드가 바꿔 둔 오늘 수치 본문이 유지되고,
    /// 더 이상 유효하지 않은 요청(예전 반복 요청, 지난 날, 오늘 이미 본 날)은 정리 대상이 된다.
    struct Plan: Equatable {
        let add: [Slot]
        let remove: [String]
    }

    static func plan(desired slots: [Slot], pending: Set<String>) -> Plan {
        let desiredIDs = Set(slots.map(\.identifier))
        return Plan(
            add: slots.filter { !pending.contains($0.identifier) },
            remove: pending.subtracting(desiredIDs).sorted()
        )
    }

    /// 앱이 떠 있는 동안(macOS) 요약을 미리 만들 시각. 다음 알림 시각의 `lead` 전이고,
    /// 이미 그 창 안이면 지금 바로. 오늘 알림 시각이 지났으면 nextFireDate 가 내일이라 내일 분이 된다.
    static func preGenerationDate(
        settings: SummaryReminderSettings,
        from now: Date = Date(),
        lead: TimeInterval = 10 * 60,
        calendar: Calendar = .current
    ) -> Date? {
        guard let fire = settings.nextFireDate(after: now, calendar: calendar) else { return nil }
        return max(fire.addingTimeInterval(-lead), now)
    }

    /// 지금 미리 생성을 해도 되는가 — 다음 알림이 "오늘" 이어야 한다. 오늘 알림 시각이 이미 지났으면(기기 잠자기 뒤
    /// 늦게 깬 경우 등) 다음 알림은 내일이라, 오늘 수치를 내일 알림 본문에 넣게 되므로 false.
    static func shouldPreGenerate(settings: SummaryReminderSettings, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard settings.isEnabled, let fire = settings.nextFireDate(after: now, calendar: calendar) else { return false }
        return dayKey(for: fire, calendar: calendar) == dayKey(for: now, calendar: calendar)
    }

    /// 백그라운드에서 요약을 만들었을 때 오늘 알림에 넣는 수치 본문.
    static func numericBody(completedEventCount: Int, productivityScore: Double) -> String {
        let percent = Int((productivityScore * 100).rounded())
        return String(localized: "오늘 \(completedEventCount)건 완료 · 생산성 \(percent)점. 눌러서 요약을 확인해 보세요.")
    }
}

// MARK: - 요약 확인 기록

/// 오늘 요약을 이미 봤으면 그날 알림을 생략하기 위해 마지막으로 본 날짜 키 하나만 저장한다.
enum SummaryReminderViewedStore {
    static let key = "summaryReminder.lastViewedDay"

    static func markViewed(on date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        defaults.set(SummaryReminderSchedule.dayKey(for: date, calendar: calendar), forKey: key)
    }

    static func hasViewed(on date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: key) == SummaryReminderSchedule.dayKey(for: date, calendar: calendar)
    }
}
