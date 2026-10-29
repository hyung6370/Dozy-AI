//
//  SearchMatcherTests.swift
//  Dozy AITests
//
//  #72 선행 리팩터링 — SearchView 에서 옮긴 키워드 매칭이 기존 동작과 같은지 고정한다.
//

import XCTest
@testable import Dozy_AI

@MainActor
final class SearchMatcherTests: XCTestCase {

    private let cal = Calendar.current

    private func date(_ day: Int, _ hour: Int = 9) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func external(
        id: String = UUID().uuidString, title: String = "외부", day: Int = 10, hour: Int = 9,
        location: String? = nil, notes: String? = nil, category: String = "일반",
        source: CalendarSource = .apple
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, calendarId: nil, title: title,
            startDate: date(day, hour), endDate: date(day, hour + 1),
            location: location, notes: notes, isAllDay: false,
            calendarName: "테스트", calendarColorHex: "#007AFF",
            source: source, priority: 0, isPinned: false, category: category
        )
    }

    private func dozy(
        id: String = UUID().uuidString, title: String = "도지", day: Int = 10, hour: Int = 9,
        location: String? = nil, notes: String? = nil, memos: [String] = [], category: String = "일반"
    ) -> DozyEvent {
        let e = DozyEvent(id: id, title: title, startDate: date(day, hour), endDate: date(day, hour + 1),
                          location: location, notes: notes, category: category)
        e.memos = memos
        return e
    }

    private func match(_ query: String, dozy: [DozyEvent] = [], external: [CalendarEvent] = [],
                       logs: [WorkLog] = [], categories: [UserCategory] = []) -> SearchResults {
        SearchMatcher.match(query: query, dozyEvents: dozy, externalEvents: external,
                            workLogs: logs, categories: categories)
    }

    // MARK: - 검색어

    func test_emptyOrWhitespaceQuery_returnsEmpty() {
        let events = [external(title: "회의")]
        XCTAssertTrue(match("", external: events).isEmpty)
        XCTAssertTrue(match("   ", external: events).isEmpty)
    }

    func test_query_isTrimmedAndCaseInsensitive() {
        let result = match("  MEETING ", external: [external(title: "Team meeting")])
        XCTAssertEqual(result.events.map(\.title), ["Team meeting"])
    }

    func test_singleCharacterQuery_matches() {
        XCTAssertEqual(match("회", external: [external(title: "회의")]).events.count, 1)
    }

    // MARK: - Dozy 일정

    func test_dozyEvent_matchesTitleLocationNotesMemosAndCategory() {
        let events = [
            dozy(title: "운동 가기"),
            dozy(title: "a", location: "운동장"),
            dozy(title: "b", notes: "운동 메모"),
            dozy(title: "c", memos: ["오늘 운동함"]),
            dozy(title: "d", category: "운동"),
            dozy(title: "무관")
        ]
        XCTAssertEqual(Set(match("운동", dozy: events).events.map(\.title)), ["운동 가기", "a", "b", "c", "d"])
    }

    // MARK: - 외부 일정

    func test_externalEvent_matchesTitleLocationNotes_butNotCategory() {
        let events = [
            external(title: "회의"),
            external(title: "a", location: "회의실"),
            external(title: "b", notes: "회의 자료"),
            external(title: "c", category: "회의")
        ]
        XCTAssertEqual(Set(match("회의", external: events).events.map(\.title)), ["회의", "a", "b"])
    }

    // MARK: - 중복 제거 · 정렬

    func test_sameIdAndStart_isDeduplicated_dozyWins() {
        let d = dozy(id: "same", title: "회의 도지")
        let e = external(id: "same", title: "회의 외부")
        let result = match("회의", dozy: [d], external: [e])
        XCTAssertEqual(result.events.map(\.title), ["회의 도지"])
    }

    func test_sameIdDifferentStart_keepsBothOccurrences() {
        let a = external(id: "rec", title: "주간 회의", day: 3)
        let b = external(id: "rec", title: "주간 회의", day: 10)
        XCTAssertEqual(match("회의", external: [a, b]).events.count, 2)
    }

    func test_events_sortedNewestFirst() {
        let events = [external(title: "회의1", day: 1), external(title: "회의3", day: 3), external(title: "회의2", day: 2)]
        XCTAssertEqual(match("회의", external: events).events.map(\.title), ["회의3", "회의2", "회의1"])
    }

    func test_eventsByDate_groupsByDayNewestFirst_keepingOrderWithinDay() {
        let events = [
            external(title: "회의 아침", day: 5, hour: 8),
            external(title: "회의 저녁", day: 5, hour: 18),
            external(title: "회의 다른날", day: 2)
        ]
        let groups = match("회의", external: events).eventsByDate
        XCTAssertEqual(groups.map(\.date), [cal.startOfDay(for: date(5)), cal.startOfDay(for: date(2))])
        XCTAssertEqual(groups[0].events.map(\.title), ["회의 저녁", "회의 아침"])
    }

    // MARK: - 카테고리 · 일지

    func test_categories_matchByName() {
        let cats = [UserCategory(name: "운동", emoji: "🏃", colorHex: "#FF0000"),
                    UserCategory(name: "업무", emoji: "💼", colorHex: "#0000FF")]
        XCTAssertEqual(match("운동", categories: cats).categories.map(\.name), ["운동"])
    }

    func test_workLogs_matchSummaryHighlightsNextActionsMemos_newestFirst() {
        func log(_ day: Int, _ configure: (WorkLog) -> Void) -> WorkLog {
            let l = WorkLog(date: date(day)); configure(l); return l
        }
        let logs = [
            log(1) { $0.aiSummary = "회의가 많았다" },
            log(2) { $0.highlights = ["회의 정리"] },
            log(3) { $0.nextActions = ["회의 준비"] },
            log(4) { $0.memos = ["회의 메모"] },
            log(5) { $0.aiSummary = "조용한 하루" }
        ]
        let result = match("회의", logs: logs)
        XCTAssertEqual(result.workLogs.map { cal.component(.day, from: $0.date) }, [4, 3, 2, 1])
    }

    // MARK: - 메모 스니펫

    func test_matchedMemo_prefersDozyMemoOverNotes() {
        let d = dozy(notes: "회의 노트", memos: ["회의 메모"])
        let ev = d.toCalendarEvent()
        XCTAssertEqual(SearchMatcher.matchedMemo(for: ev, dozyEvent: d, query: "회의"), "회의 메모")
    }

    func test_matchedMemo_fallsBackToNotes() {
        let ev = external(notes: "회의 노트")
        XCTAssertEqual(SearchMatcher.matchedMemo(for: ev, dozyEvent: nil, query: "회의"), "회의 노트")
        XCTAssertNil(SearchMatcher.matchedMemo(for: external(notes: "무관"), dozyEvent: nil, query: "회의"))
        XCTAssertNil(SearchMatcher.matchedMemo(for: ev, dozyEvent: nil, query: " "))
    }

    func test_matchedMemos_inLog_filtersByQuery() {
        let l = WorkLog(date: date(1))
        l.memos = ["회의 메모", "점심", "회의 후기"]
        XCTAssertEqual(SearchMatcher.matchedMemos(in: l, query: "회의"), ["회의 메모", "회의 후기"])
    }
}
