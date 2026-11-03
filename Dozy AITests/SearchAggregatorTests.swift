//
//  SearchAggregatorTests.swift
//  Dozy AITests
//
//  #72 — 자연어 질의 집계(SearchAggregator)와 UseCase(SearchEventsUseCase · ParseSearchQueryUseCase).
//  "AI 는 해석만, 숫자는 Swift 가" — 수치가 여기서 고정된다.
//

import XCTest
import Combine
@testable import Dozy_AI

private let cal = Calendar.current

private func date(_ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
}

private func event(
    _ title: String, id: String = UUID().uuidString,
    start: Date, end: Date, allDay: Bool = false,
    source: CalendarSource = .apple, category: String = "일반",
    location: String? = nil, notes: String? = nil
) -> CalendarEvent {
    CalendarEvent(
        id: id, calendarId: nil, title: title, startDate: start, endDate: end,
        location: location, notes: notes, isAllDay: allDay,
        calendarName: "테스트", calendarColorHex: "#007AFF",
        source: source, priority: 0, isPinned: false, category: category
    )
}

/// 2026-10-19(월) ~ 10-26(월) — "지난주"
private let lastWeek = SearchQueryIntent.Period(start: date(10, 19), end: date(10, 26), label: "지난주")

@MainActor
final class SearchAggregatorTests: XCTestCase {

    // MARK: - 필터

    func test_filter_excludesHolidays_andOutsidePeriod_newestFirst() {
        let events = [
            event("회의 A", start: date(10, 20, 10), end: date(10, 20, 11)),
            event("회의 B", start: date(10, 22, 10), end: date(10, 22, 11)),
            event("회의 공휴일", start: date(10, 21), end: date(10, 21), allDay: true, source: .holiday),
            event("회의 범위 밖", start: date(10, 27, 10), end: date(10, 27, 11)),
        ]
        let intent = SearchQueryIntent(period: lastWeek, keyword: "회의")
        XCTAssertEqual(SearchAggregator.filter(events, intent: intent).map(\.title), ["회의 B", "회의 A"])
    }

    func test_filter_multiWordKeyword_requiresAllTokens_acrossFields() {
        let events = [
            event("팀 회의", start: date(10, 20, 10), end: date(10, 20, 11)),
            event("회의", start: date(10, 20, 12), end: date(10, 20, 13), location: "팀 라운지"),
            event("회의", start: date(10, 20, 14), end: date(10, 20, 15)),
        ]
        let intent = SearchQueryIntent(period: lastWeek, keyword: "팀 회의")
        XCTAssertEqual(SearchAggregator.filter(events, intent: intent).count, 2)
    }

    func test_filter_categoryHint_matchesCategoryEvenWithoutTitle() {
        let events = [
            event("헬스", start: date(10, 20, 7), end: date(10, 20, 8), category: "운동"),
            event("운동화 사기", start: date(10, 21, 7), end: date(10, 21, 8)),
            event("점심", start: date(10, 21, 12), end: date(10, 21, 13)),
        ]
        let intent = SearchQueryIntent(period: lastWeek, keyword: "운동", categoryHint: "운동")
        XCTAssertEqual(Set(SearchAggregator.filter(events, intent: intent).map(\.title)), ["헬스", "운동화 사기"])
    }

    func test_filter_noKeyword_returnsAllInPeriod() {
        let events = [event("아무거나", start: date(10, 20, 7), end: date(10, 20, 8))]
        XCTAssertEqual(SearchAggregator.filter(events, intent: SearchQueryIntent(period: lastWeek)).count, 1)
    }

    // MARK: - 집계

    func test_totalMinutes_excludesAllDay_andClipsAtPeriodBoundary() {
        let events = [
            event("회의", start: date(10, 20, 10), end: date(10, 20, 11, 30)),       // 90분
            event("회의", start: date(10, 22, 14), end: date(10, 22, 15)),           // 60분
            event("회의 종일", start: date(10, 23), end: date(10, 23), allDay: true), // 제외
            event("회의 경계", start: date(10, 25, 23), end: date(10, 26, 1)),        // 60분만 (자정까지)
        ]
        let a = SearchAggregator.aggregate(events, aggregation: .totalHours, period: lastWeek, completion: .init())
        XCTAssertEqual(a.eventCount, 4)
        XCTAssertEqual(a.totalMinutes, 210)
        XCTAssertEqual(a.allDayCount, 1)
    }

    func test_completion_followsToggleRules() {
        let dozyDone = event("Dozy 완료", id: "d1", start: date(10, 20, 9), end: date(10, 20, 10), source: .dozy)
        let dozyOpen = event("Dozy 미완료", id: "d2", start: date(10, 20, 11), end: date(10, 20, 12), source: .dozy)
        let recurringDozy = event("반복 Dozy", id: "r1", start: date(10, 21, 9), end: date(10, 21, 10), source: .dozy)
        let appleDone = event("애플", id: "a1", start: date(10, 22, 9), end: date(10, 22, 10))
        let appleOtherDay = event("애플", id: "a1", start: date(10, 23, 9), end: date(10, 23, 10))
        let lookup = CompletionLookup(
            nonRecurringDozy: ["d1": true, "d2": false],
            completedKeys: [
                CompletionLookup.key(eventID: "r1", day: date(10, 21)),
                CompletionLookup.key(eventID: "a1", day: date(10, 22)),
            ]
        )
        let events = [dozyDone, dozyOpen, recurringDozy, appleDone, appleOtherDay]
        let a = SearchAggregator.aggregate(events, aggregation: .completionRate, period: lastWeek, completion: lookup)
        XCTAssertEqual(a.completedCount, 3)
        XCTAssertEqual(a.completionRate ?? -1, 0.6, accuracy: 0.0001)
    }

    func test_completionRate_nilWhenNoEvents() {
        let a = SearchAggregator.aggregate([], aggregation: .completionRate, period: lastWeek, completion: .init())
        XCTAssertNil(a.completionRate)
    }
}

// MARK: - UseCase

@MainActor
final class SearchQueryUseCaseTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    func test_searchEvents_noPeriod_returnsEmptyWithoutFetching() throws {
        let calendar = MockPeriodCalendarService()
        let useCase = makeSearchUseCase(calendar: calendar)
        let result = try awaitPublisher(useCase.execute(SearchQueryIntent(keyword: "회의")))
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertNil(result.aggregate)
        XCTAssertTrue(calendar.rangeCalls.isEmpty)
    }

    func test_searchEvents_fetchesPeriod_filters_andAggregates() throws {
        let calendar = MockPeriodCalendarService()
        calendar.stubbedEvents = [
            event("주간 회의", id: "a1", start: date(10, 20, 10), end: date(10, 20, 11)),
            event("회의", id: "d1", start: date(10, 21, 10), end: date(10, 21, 10, 30), source: .dozy),
            event("점심", start: date(10, 21, 12), end: date(10, 21, 13)),
            event("회의 공휴일", start: date(10, 22), end: date(10, 22), allDay: true, source: .holiday),
        ]
        let dozyRepo = MockDozyEventRepository()
        let done = DozyEvent(id: "d1", title: "회의", startDate: date(10, 21, 10), endDate: date(10, 21, 10, 30))
        done.isCompleted = true
        dozyRepo.stubbedPeriodEvents = [done]
        let completionRepo = MockEventCompletionRepository()

        let useCase = makeSearchUseCase(calendar: calendar, dozyRepo: dozyRepo, completionRepo: completionRepo)
        let intent = SearchQueryIntent(period: lastWeek, keyword: "회의", aggregation: .totalHours)
        let result = try awaitPublisher(useCase.execute(intent))

        XCTAssertEqual(calendar.rangeCalls.first?.start, lastWeek.start)
        XCTAssertEqual(calendar.rangeCalls.first?.end, lastWeek.end)
        XCTAssertEqual(result.events.map(\.title), ["회의", "주간 회의"])
        XCTAssertEqual(result.aggregate?.totalMinutes, 90)
        XCTAssertEqual(result.aggregate?.completedCount, 1)
    }

    func test_searchEvents_periodOnly_hasNoAggregate() throws {
        let calendar = MockPeriodCalendarService()
        calendar.stubbedEvents = [event("회의", start: date(10, 20, 10), end: date(10, 20, 11))]
        let result = try awaitPublisher(makeSearchUseCase(calendar: calendar)
            .execute(SearchQueryIntent(period: lastWeek, keyword: "회의")))
        XCTAssertEqual(result.events.count, 1)
        XCTAssertNil(result.aggregate)
    }

    func test_parseSearchQuery_tracksKindAndEngine_once() async {
        let parser = MockQueryParsingService()
        parser.stubbedIntent = SearchQueryIntent(period: lastWeek, keyword: "회의", aggregation: .count, source: .onDevice)
        let analytics = MockAnalyticsService()
        let useCase = ParseSearchQueryUseCase(parser: parser, analytics: analytics)

        let intent = await useCase.execute(text: "지난주 회의 몇 번", categories: ["업무"])

        XCTAssertEqual(intent.kind, .aggregate)
        XCTAssertEqual(parser.receivedCategories, ["업무"])
        XCTAssertEqual(analytics.trackedEvents, [.searchQuery(kind: .aggregate, engine: .onDevice)])
    }

    private func makeSearchUseCase(
        calendar: MockPeriodCalendarService,
        dozyRepo: MockDozyEventRepository = MockDozyEventRepository(),
        completionRepo: MockEventCompletionRepository = MockEventCompletionRepository()
    ) -> SearchEventsUseCase {
        SearchEventsUseCase(
            fetchEvents: FetchCalendarEventsForPeriodUseCase(calendarService: calendar),
            fetchDozyEvents: FetchDozyEventsForPeriodUseCase(repository: dozyRepo),
            fetchCompletions: FetchEventCompletionsForPeriodUseCase(repository: completionRepo)
        )
    }
}
