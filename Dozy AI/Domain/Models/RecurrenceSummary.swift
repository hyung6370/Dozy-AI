//
//  RecurrenceSummary.swift
//  Dozy AI
//
//  반복 일정 입력 · 표시용 순수 계산 (#147).
//  - 규칙 제목: 시작일 기준으로 무엇이 반복되는지 붙인다 — "매주 (목요일)" · "매월 (30일)" · "매년 (10월 30일)"
//  - 요약: "매주 목요일 · 2027년 10월 30일까지" / "매주 목요일 · 계속"
//  - 종료일: 기본값(시작 + 1년)과 보정(시작일보다 앞이면 시작일로)
//  규칙 문자열(`none/daily/weekly/monthly/yearly`)은 그대로 둔다 — 구버전 · 파트너 기기 호환 (#148).
//

import Foundation

nonisolated enum RecurrenceSummary {

    /// 편집 화면 메뉴 순서
    static let rules = ["none", "daily", "weekly", "monthly", "yearly"]

    // MARK: - 종료일

    /// "날짜 지정"을 처음 켰을 때의 종료일 — 시작일로부터 1년 뒤
    static func defaultEndDate(for start: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .year, value: 1, to: start) ?? start
    }

    /// 종료일이 시작일(날짜 기준)보다 앞이면 시작일로 당긴다 — 그대로 두면 반복이 하나도 생기지 않는다.
    static func adjustedEndDate(_ end: Date, start: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: end) < calendar.startOfDay(for: start) ? start : end
    }

    // MARK: - 문구

    /// 메뉴 항목 제목. 반복 없음 · 매일은 덧붙일 정보가 없다.
    static func ruleTitle(_ rule: String, start: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch rule {
        case "daily":
            return String(localized: "매일")
        case "weekly":
            return String(localized: "매주 (\(weekdayName(start, calendar: calendar, locale: locale)))")
        case "monthly":
            return String(localized: "매월 (\(calendar.component(.day, from: start))일)")
        case "yearly":
            return String(localized: "매년 (\(monthDay(start, calendar: calendar, locale: locale)))")
        default:
            return String(localized: "없음")
        }
    }

    /// 반복 요약. 반복이 없으면 nil.
    /// - endDate: nil 이면 계속 반복
    static func summary(rule: String, start: Date, endDate: Date?, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        let pattern: String
        switch rule {
        case "daily":
            pattern = String(localized: "매일")
        case "weekly":
            pattern = String(localized: "매주 \(weekdayName(start, calendar: calendar, locale: locale))")
        case "monthly":
            pattern = String(localized: "매월 \(calendar.component(.day, from: start))일")
        case "yearly":
            pattern = String(localized: "매년 \(monthDay(start, calendar: calendar, locale: locale))")
        default:
            return nil
        }
        let until: String
        if let endDate {
            until = String(localized: "\(fullDate(endDate, calendar: calendar, locale: locale))까지")
        } else {
            until = String(localized: "계속")
        }
        return "\(pattern) · \(until)"
    }

    // MARK: - 날짜 조각

    static func weekdayName(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        format(date, template: "EEEE", calendar: calendar, locale: locale)
    }

    static func monthDay(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        format(date, template: "MMMMd", calendar: calendar, locale: locale)
    }

    static func fullDate(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        format(date, template: "yMMMMd", calendar: calendar, locale: locale)
    }

    private static func format(_ date: Date, template: String, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
