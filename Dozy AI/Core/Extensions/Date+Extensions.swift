//
//  Date+Extensions.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation

extension Date {
    
    /// 해당 날짜의 시작 시점 (00:00:00)
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// 해당 날짜의 끝 시점 (23:59:59)
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
    }
    
    /// 다음 날 시작 시점
    var startOfNextDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    }
    
    /// 요일 번호 (1=일, 2=월, ..., 7=토)
    var weekdayNumber: Int {
        Calendar.current.component(.weekday, from: self)
    }
    
    /// 짧은 요일 — 현재 locale 의 1글자 심볼 (ko: "일/월/...", en: "S/M/...").
    var weekdayString: String {
        var cal = Calendar.current
        cal.locale = .current
        // weekdayNumber 는 1=Sun ~ 7=Sat, veryShortWeekdaySymbols 는 0-indexed 라 -1.
        return cal.veryShortWeekdaySymbols[weekdayNumber - 1]
    }

    /// 현재 locale 의 짧은 날짜 — ko: "3월 18일 (화)" / en: "Mar 18 (Tue)".
    /// dateFormat 자체를 catalog 키로 등록해 locale 별 ICU 패턴을 분기시킨다.
    var formattedKorean: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = String(localized: "M월 d일 (E)")
        return f.string(from: self)
    }

    /// 현재 locale 의 12시간제 시각 — ko: "오후 2:30" / en: "2:30 PM".
    var formattedTime: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = String(localized: "a h:mm")
        return f.string(from: self)
    }
    
    /// n일 전 날짜
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self)!
    }
}
