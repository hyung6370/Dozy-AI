//
//  SummaryReminderSettings.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/23/26.
//

// 저녁 요약 알림 설정 값 타입. UserDefaults에 저장하고 설정 화면/스케줄러가 공유한다.

import Foundation

struct SummaryReminderSettings: Equatable {
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
