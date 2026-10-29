//
//  QueryRuleParserTests.swift
//  Dozy AITests
//
//  #72 — 자연어 질의 규칙 해석기. iOS 26 미만 기기의 유일한 경로라 기간 경계를 촘촘히 고정한다.
//  주 시작은 월요일 (#72 결정). 기준일 2026-10-29 목요일.
//

import XCTest
@testable import Dozy_AI

final class QueryRuleParserTests: XCTestCase {

    private let cal = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    /// 2026-10-29 (목) 12:00
    private var thursday: Date { date(2026, 10, 29, 12) }

    private func parse(_ text: String, at ref: Date? = nil, categories: [String] = []) -> SearchQueryIntent {
        QueryRuleParser.parse(text, referenceDate: ref ?? thursday, categories: categories)
    }

    private func assertPeriod(_ text: String, at ref: Date? = nil, _ start: Date, _ end: Date,
                              file: StaticString = #filePath, line: UInt = #line) {
        let period = parse(text, at: ref).period
        XCTAssertEqual(period?.start, start, "\(text) 시작", file: file, line: line)
        XCTAssertEqual(period?.end, end, "\(text) 끝", file: file, line: line)
    }

    // MARK: - 주 (월요일 시작)

    func test_lastWeek_isPreviousMondayToMonday() {
        assertPeriod("지난주", date(2026, 10, 19), date(2026, 10, 26))
        assertPeriod("저번 주", date(2026, 10, 19), date(2026, 10, 26))
        assertPeriod("last week", date(2026, 10, 19), date(2026, 10, 26))
    }

    func test_thisWeek_onThursday() {
        assertPeriod("이번 주", date(2026, 10, 26), date(2026, 11, 2))
    }

    func test_onSunday_weekStillStartsMonday() {
        let sunday = date(2026, 11, 1, 12)
        assertPeriod("이번주", at: sunday, date(2026, 10, 26), date(2026, 11, 2))
        assertPeriod("지난주", at: sunday, date(2026, 10, 19), date(2026, 10, 26))
    }

    func test_onMonday_lastWeekIsPreviousFullWeek() {
        assertPeriod("지난주", at: date(2026, 11, 2, 9), date(2026, 10, 26), date(2026, 11, 2))
    }

    // MARK: - 달 · 해

    func test_thisMonth_and_lastMonth() {
        assertPeriod("이번 달", date(2026, 10, 1), date(2026, 11, 1))
        assertPeriod("지난달", date(2026, 9, 1), date(2026, 10, 1))
        assertPeriod("this month", date(2026, 10, 1), date(2026, 11, 1))
    }

    func test_lastMonth_crossesYearBoundary() {
        assertPeriod("지난달", at: date(2027, 1, 15, 12), date(2026, 12, 1), date(2027, 1, 1))
    }

    func test_thisYear() {
        assertPeriod("올해", date(2026, 1, 1), date(2027, 1, 1))
    }

    // MARK: - 날 · 최근 N

    func test_today_and_yesterday() {
        assertPeriod("오늘", date(2026, 10, 29), date(2026, 10, 30))
        assertPeriod("어제", date(2026, 10, 28), date(2026, 10, 29))
    }

    func test_recentNDays_includesToday() {
        assertPeriod("최근 7일", date(2026, 10, 23), date(2026, 10, 30))
        assertPeriod("last 7 days", date(2026, 10, 23), date(2026, 10, 30))
        assertPeriod("최근 일주일", date(2026, 10, 23), date(2026, 10, 30))
    }

    func test_recentNWeeks() {
        assertPeriod("최근 2주", date(2026, 10, 16), date(2026, 10, 30))
    }

    func test_recentNMonths() {
        assertPeriod("최근 3개월", date(2026, 7, 30), date(2026, 10, 30))
        assertPeriod("최근 한 달", date(2026, 9, 30), date(2026, 10, 30))
    }

    func test_periodLabels() {
        XCTAssertEqual(parse("최근 7일").period?.label, String(localized: "최근 \(7)일"))
        XCTAssertEqual(parse("지난주").period?.label, String(localized: "지난주"))
    }

    // MARK: - 집계 · 키워드

    func test_lastWeekMeetingHours() {
        let intent = parse("지난주 회의 몇 시간 썼지?")
        XCTAssertEqual(intent.aggregation, .totalHours)
        XCTAssertEqual(intent.keyword, "회의")
        XCTAssertEqual(intent.period?.start, date(2026, 10, 19))
        XCTAssertEqual(intent.kind, .aggregate)
        XCTAssertEqual(intent.source, .rules)
    }

    func test_thisMonthWorkoutCount_withCategoryHint() {
        let intent = parse("이번달 운동 몇 번 했어", categories: ["업무", "운동"])
        XCTAssertEqual(intent.aggregation, .count)
        XCTAssertEqual(intent.keyword, "운동")
        XCTAssertEqual(intent.categoryHint, "운동")
    }

    func test_english_hoursQuery() {
        let intent = parse("how many hours did I spend in meetings last week")
        XCTAssertEqual(intent.aggregation, .totalHours)
        XCTAssertEqual(intent.keyword, "meetings")
        XCTAssertEqual(intent.period?.start, date(2026, 10, 19))
    }

    func test_howManyTimes_isCount() {
        XCTAssertEqual(parse("how many times gym this month").aggregation, .count)
    }

    func test_completionRate_withoutKeyword() {
        let intent = parse("이번 달 완료율")
        XCTAssertEqual(intent.aggregation, .completionRate)
        XCTAssertNil(intent.keyword)
    }

    func test_singleKeyword_staysKeywordSearch() {
        let intent = parse("회의")
        XCTAssertNil(intent.period)
        XCTAssertEqual(intent.aggregation, .none)
        XCTAssertEqual(intent.keyword, "회의")
        XCTAssertEqual(intent.kind, .keyword)
    }

    func test_aggregationWithoutPeriod_defaultsToThisMonth() {
        let intent = parse("회의 몇 번")
        XCTAssertEqual(intent.period?.start, date(2026, 10, 1))
        XCTAssertEqual(intent.period?.end, date(2026, 11, 1))
        XCTAssertEqual(intent.period?.isDefault, true)
        XCTAssertEqual(intent.kind, .aggregate)
    }

    func test_periodWithoutAggregation_isPeriodKind() {
        let intent = parse("지난주 회의")
        XCTAssertEqual(intent.kind, .period)
        XCTAssertEqual(intent.keyword, "회의")
    }

    func test_particles_stripped_butMeetingKept() {
        XCTAssertEqual(parse("지난주 회의에").keyword, "회의")
        XCTAssertEqual(parse("지난주 운동은").keyword, "운동")
        XCTAssertEqual(QueryRuleParser.extractKeyword(from: "회의"), "회의")
    }

    func test_isMultiWord() {
        XCTAssertFalse(QueryRuleParser.isMultiWord("회의"))
        XCTAssertFalse(QueryRuleParser.isMultiWord("  회의  "))
        XCTAssertTrue(QueryRuleParser.isMultiWord("지난주 회의"))
    }

    // MARK: - 모델 결과 병합

    private func merge(_ model: ModelQueryInterpretation, text: String, categories: [String] = []) -> SearchQueryIntent {
        let rules = QueryRuleParser.parse(text, referenceDate: thursday, categories: categories)
        return QueryRuleParser.merge(model: model, rules: rules, text: text,
                                     referenceDate: thursday, categories: categories)
    }

    func test_merge_usesModelPeriod_whenRulesHaveNone() {
        let intent = merge(.init(startDate: "2026-10-01", endDate: "2026-10-07", keyword: "회의", category: nil,
                                 aggregation: .count), text: "시월 첫 주 회의 몇 번")
        XCTAssertEqual(intent.period?.start, date(2026, 10, 1))
        XCTAssertEqual(intent.period?.end, date(2026, 10, 8))
        XCTAssertEqual(intent.period?.isDefault, false)
        XCTAssertEqual(intent.source, .onDevice)
    }

    func test_merge_rulesPeriodWins_forDictionaryPhrase() {
        let intent = merge(.init(startDate: "2026-10-12", endDate: "2026-10-18", keyword: "회의", category: nil,
                                 aggregation: .totalHours), text: "지난주 회의 몇 시간")
        XCTAssertEqual(intent.period?.start, date(2026, 10, 19))
    }

    func test_merge_dropsInventedKeyword_andUnknownCategory() {
        let intent = merge(.init(startDate: nil, endDate: nil, keyword: "미팅", category: "없는카테고리",
                                 aggregation: .totalHours), text: "지난주 회의 몇 시간", categories: ["업무"])
        XCTAssertEqual(intent.keyword, "회의")
        XCTAssertNil(intent.categoryHint)
    }

    func test_merge_acceptsKnownCategory() {
        let intent = merge(.init(startDate: nil, endDate: nil, keyword: "운동", category: "운동",
                                 aggregation: .count), text: "지난주 운동 몇 번", categories: ["운동"])
        XCTAssertEqual(intent.categoryHint, "운동")
    }

    func test_merge_modelAggregationFillsRulesGap() {
        let intent = merge(.init(startDate: nil, endDate: nil, keyword: "회의", category: nil,
                                 aggregation: .totalHours), text: "지난주 회의 얼마나 했는지")
        XCTAssertEqual(intent.aggregation, .totalHours)
    }

    func test_modelPeriod_rejectsInvalidDates() {
        let c = Calendar.mondayFirst()
        XCTAssertNil(QueryRuleParser.period(fromModelStart: "2026-02-30", end: nil, calendar: c))
        XCTAssertNil(QueryRuleParser.period(fromModelStart: "2026-10-10", end: "2026-10-01", calendar: c))
        XCTAssertNil(QueryRuleParser.period(fromModelStart: "2020-01-01", end: "2026-01-01", calendar: c))
        XCTAssertNil(QueryRuleParser.period(fromModelStart: "어제", end: nil, calendar: c))
        XCTAssertEqual(QueryRuleParser.period(fromModelStart: "2026-10-05", end: nil, calendar: c)?.end, date(2026, 10, 6))
    }
}
