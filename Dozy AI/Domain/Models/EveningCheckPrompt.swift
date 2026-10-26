//
//  EveningCheckPrompt.swift
//  Dozy AI
//
//  저녁 일정 체크 프롬프트의 노출 조건과 대상 일정 계산 (순수 함수).
//  18:00 이후 앱을 열었을 때, 오늘 아직 안 보여줬고, 이미 끝났는데 완료 체크가 없는 일정이 있으면 하루 1회 띄운다.
//  자정을 넘기면 어제 일정은 묻지 않는다 (날짜 키가 바뀌므로 자연히 패스).
//

import Foundation

enum EveningCheckPrompt {

    static let enabledKey = "eveningCheck.isEnabled"
    static let lastShownDayKey = "eveningCheck.lastShownDay"
    /// 이 시각(시) 이후부터 자정 전까지가 노출 시간대.
    static let windowStartHour = 18

    static func isInWindow(_ now: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: now) >= windowStartHour
    }

    /// 체크를 물어볼 일정: 완료 체크가 없고, 공휴일(읽기 전용)이 아니고, 이미 끝났거나 종일인 일정. 시작 시각 순.
    /// 아직 안 끝난 시간제 일정은 "안 한 것"이 아니라 "아직 안 온 것"이라 제외한다.
    static func targetEvents(_ events: [CalendarEvent], completions: [String: Bool], now: Date) -> [CalendarEvent] {
        events
            .filter { completions[$0.id] != true && !$0.isReadOnly && ($0.isAllDay || $0.endDate <= now) }
            .sorted { $0.startDate < $1.startDate }
    }

    static func shouldPrompt(
        now: Date,
        isEnabled: Bool,
        lastShownDay: String?,
        targetCount: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard isEnabled, targetCount > 0, isInWindow(now, calendar: calendar) else { return false }
        return lastShownDay != SummaryReminderSchedule.dayKey(for: now, calendar: calendar)
    }

    // MARK: - 저장

    enum Store {
        /// 기본값은 켜짐.
        static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
            defaults.object(forKey: EveningCheckPrompt.enabledKey) == nil
                ? true
                : defaults.bool(forKey: EveningCheckPrompt.enabledKey)
        }

        static func lastShownDay(defaults: UserDefaults = .standard) -> String? {
            defaults.string(forKey: EveningCheckPrompt.lastShownDayKey)
        }

        /// 오늘 보여줬다고 기록한다. 시트를 그냥 닫아도 그날은 다시 띄우지 않는다.
        static func markShown(on date: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
            defaults.set(SummaryReminderSchedule.dayKey(for: date, calendar: calendar), forKey: EveningCheckPrompt.lastShownDayKey)
        }
    }
}
