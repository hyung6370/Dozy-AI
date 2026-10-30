//
//  RecurrenceSummaryTests.swift
//  Dozy AITests
//
//  반복 일정 입력 · 표시 순수 계산 (#147). iOS · macOS 테스트 타깃 공통.
//  문구는 앱 언어(ko/en)에 따라 바뀌므로, 요일 · 날짜 조각과 구조(계속 / 날짜까지)를 확인한다.
//

import XCTest
@testable import Dozy_AI

final class RecurrenceSummaryTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private let ko = Locale(identifier: "ko_KR")

    /// 2026-10-29 (목) 09:00
    private var start: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9))!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    // MARK: - 종료일

    func test_defaultEndDate_isOneYearAfterStart() {
        XCTAssertEqual(RecurrenceSummary.defaultEndDate(for: start, calendar: calendar), date(2027, 10, 29, hour: 9))
    }

    func test_adjustedEndDate_beforeStart_movesToStart() {
        XCTAssertEqual(RecurrenceSummary.adjustedEndDate(date(2026, 10, 1), start: start, calendar: calendar), start)
    }

    func test_adjustedEndDate_sameDayEarlierTime_keepsEnd() {
        // 같은 날이면 그날 반복이 생기므로 그대로 둔다 (DatePicker 는 날짜만 고른다)
        let end = date(2026, 10, 29)
        XCTAssertEqual(RecurrenceSummary.adjustedEndDate(end, start: start, calendar: calendar), end)
    }

    func test_adjustedEndDate_afterStart_keepsEnd() {
        let end = date(2026, 12, 31)
        XCTAssertEqual(RecurrenceSummary.adjustedEndDate(end, start: start, calendar: calendar), end)
    }

    // MARK: - 날짜 조각

    func test_dateParts_korean() {
        XCTAssertEqual(RecurrenceSummary.weekdayName(start, calendar: calendar, locale: ko), "목요일")
        XCTAssertEqual(RecurrenceSummary.monthDay(start, calendar: calendar, locale: ko), "10월 29일")
        XCTAssertEqual(RecurrenceSummary.fullDate(date(2027, 10, 29), calendar: calendar, locale: ko), "2027년 10월 29일")
    }

    // MARK: - 규칙 제목

    func test_ruleTitle_addsStartContext() {
        XCTAssertTrue(RecurrenceSummary.ruleTitle("weekly", start: start, calendar: calendar, locale: ko).contains("목요일"))
        XCTAssertTrue(RecurrenceSummary.ruleTitle("monthly", start: start, calendar: calendar, locale: ko).contains("29"))
        XCTAssertTrue(RecurrenceSummary.ruleTitle("yearly", start: start, calendar: calendar, locale: ko).contains("10월 29일"))
    }

    func test_ruleTitle_noneAndDaily_haveNoDateContext() {
        for rule in ["none", "daily"] {
            let title = RecurrenceSummary.ruleTitle(rule, start: start, calendar: calendar, locale: ko)
            XCTAssertFalse(title.contains("목요일"), rule)
            XCTAssertFalse(title.contains("29"), rule)
        }
    }

    func test_rules_menuOrder() {
        XCTAssertEqual(RecurrenceSummary.rules, ["none", "daily", "weekly", "monthly", "yearly"])
    }

    // MARK: - 요약

    func test_summary_none_isNil() {
        XCTAssertNil(RecurrenceSummary.summary(rule: "none", start: start, endDate: nil, calendar: calendar, locale: ko))
    }

    func test_summary_withEndDate_includesPatternAndEnd() {
        let summary = RecurrenceSummary.summary(rule: "weekly", start: start, endDate: date(2027, 10, 29),
                                                calendar: calendar, locale: ko)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("목요일"))
        XCTAssertTrue(summary!.contains("2027년 10월 29일"))
        XCTAssertTrue(summary!.contains(" · "))
    }

    func test_summary_withoutEndDate_differsAndHasNoEndDate() {
        let forever = RecurrenceSummary.summary(rule: "weekly", start: start, endDate: nil, calendar: calendar, locale: ko)
        let until = RecurrenceSummary.summary(rule: "weekly", start: start, endDate: date(2027, 10, 29), calendar: calendar, locale: ko)
        XCTAssertNotNil(forever)
        XCTAssertNotEqual(forever, until)
        XCTAssertFalse(forever!.contains("2027"))
    }

    func test_summary_monthlyAndYearly_useStartDay() {
        let monthly = RecurrenceSummary.summary(rule: "monthly", start: start, endDate: nil, calendar: calendar, locale: ko)!
        let yearly = RecurrenceSummary.summary(rule: "yearly", start: start, endDate: nil, calendar: calendar, locale: ko)!
        XCTAssertTrue(monthly.contains("29"))
        XCTAssertTrue(yearly.contains("10월 29일"))
    }
}
