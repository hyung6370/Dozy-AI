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
    
    /// 한국어 요일 문자열
    var weekdayString: String {
        let weekdays = ["", "일", "월", "화", "수", "목", "금", "토"]
        return weekdays[weekdayNumber]
    }
    
    /// "3월 18일 (화)" 형태
    var formattedKorean: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: self)
    }
    
    /// "오후 2:30" 형태
    var formattedTime: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: self)
    }
    
    /// n일 전 날짜
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self)!
    }
}
