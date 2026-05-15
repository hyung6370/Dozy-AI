//
//  TodayEventCacheWriterTests.swift
//  Dozy AITests
//
//  위젯 TodayEventCache 미러 로직을 in-memory SwiftData 컨테이너 위에서 단위 검증.
//  실제 App Group store 와 무관하게 동작 — Schema 만 같으면 동일 코드 경로.
//

import XCTest
import SwiftData
@testable import Dozy_AI

@MainActor
final class TodayEventCacheWriterTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            TodayEventCache.self,
            DozyEvent.self,
            EventCompletion.self,
            UserCategory.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - upsertSingleDozyEvent

    func test_upsertSingleDozyEvent_insertsTodayEvent() throws {
        let event = makeDozyEvent(title: "오늘 일정", startHour: 9, endHour: 10)

        TodayEventCacheWriter.upsertSingleDozyEvent(event, container: container)

        let cached = try fetchAllCache()
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.id, event.id)
        XCTAssertEqual(cached.first?.title, "오늘 일정")
    }

    func test_upsertSingleDozyEvent_replacesSameID() throws {
        let event = makeDozyEvent(title: "원본", startHour: 9, endHour: 10)
        TodayEventCacheWriter.upsertSingleDozyEvent(event, container: container)

        // 같은 id 로 제목만 변경해 한 번 더 호출.
        event.title = "수정됨"
        TodayEventCacheWriter.upsertSingleDozyEvent(event, container: container)

        let cached = try fetchAllCache()
        XCTAssertEqual(cached.count, 1, "같은 id 의 이전 row 가 교체돼야 함")
        XCTAssertEqual(cached.first?.title, "수정됨")
    }

    func test_upsertSingleDozyEvent_skipsFutureEvent() throws {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let future = makeDozyEvent(
            title: "내일 일정",
            startDate: tomorrow,
            endDate: cal.date(byAdding: .hour, value: 1, to: tomorrow)!
        )

        TodayEventCacheWriter.upsertSingleDozyEvent(future, container: container)

        let cached = try fetchAllCache()
        XCTAssertTrue(cached.isEmpty, "오늘 범위가 아닌 일정은 캐시에 들어가면 안 됨")
    }

    func test_upsertSingleDozyEvent_skipsPastEvent() throws {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let past = makeDozyEvent(
            title: "어제 일정",
            startDate: yesterday,
            endDate: cal.date(byAdding: .hour, value: 1, to: yesterday)!
        )

        TodayEventCacheWriter.upsertSingleDozyEvent(past, container: container)

        let cached = try fetchAllCache()
        XCTAssertTrue(cached.isEmpty)
    }

    // MARK: - removeSingleEvent

    func test_removeSingleEvent_removesMatchingID() throws {
        let event = makeDozyEvent(title: "삭제 대상", startHour: 9, endHour: 10)
        TodayEventCacheWriter.upsertSingleDozyEvent(event, container: container)
        XCTAssertEqual(try fetchAllCache().count, 1)

        TodayEventCacheWriter.removeSingleEvent(id: event.id, container: container)

        XCTAssertTrue(try fetchAllCache().isEmpty)
    }

    func test_removeSingleEvent_noOpForUnknownID() throws {
        let event = makeDozyEvent(title: "유지", startHour: 9, endHour: 10)
        TodayEventCacheWriter.upsertSingleDozyEvent(event, container: container)

        TodayEventCacheWriter.removeSingleEvent(id: "존재하지-않는-id", container: container)

        XCTAssertEqual(try fetchAllCache().count, 1, "다른 row 는 영향 받지 않아야 함")
    }

    // MARK: - upsert(events:completions:...)

    func test_upsertEvents_wipesAndInserts() throws {
        // 1차 — 기존 row 3개 시드.
        let seeds = [
            makeDozyEvent(title: "A", startHour: 8, endHour: 9),
            makeDozyEvent(title: "B", startHour: 10, endHour: 11),
            makeDozyEvent(title: "C", startHour: 14, endHour: 15),
        ]
        for s in seeds { TodayEventCacheWriter.upsertSingleDozyEvent(s, container: container) }
        XCTAssertEqual(try fetchAllCache().count, 3)

        // 2차 — 다른 set 으로 upsert. 이전 row 들이 전부 wipe 되고 새 events 만 남아야 함.
        let new = [makeTestEvent(title: "신규-1"), makeTestEvent(title: "신규-2")]
        TodayEventCacheWriter.upsert(
            events: new,
            completions: [:],
            dozyEventsByID: [:],
            container: container
        )

        let cached = try fetchAllCache()
        XCTAssertEqual(cached.count, 2)
        XCTAssertEqual(Set(cached.map(\.title)), Set(["신규-1", "신규-2"]))
    }

    func test_upsertEvents_appliesCompletionDict() throws {
        let event = makeTestEvent(title: "완료된 일정")
        TodayEventCacheWriter.upsert(
            events: [event],
            completions: [event.id: true],
            dozyEventsByID: [:],
            container: container
        )

        let cached = try fetchAllCache()
        XCTAssertEqual(cached.count, 1)
        XCTAssertTrue(cached.first?.isCompleted == true)
    }

    func test_upsertEvents_emptyClearsCache() throws {
        let seed = makeDozyEvent(title: "seed", startHour: 9, endHour: 10)
        TodayEventCacheWriter.upsertSingleDozyEvent(seed, container: container)
        XCTAssertEqual(try fetchAllCache().count, 1)

        TodayEventCacheWriter.upsert(
            events: [],
            completions: [:],
            dozyEventsByID: [:],
            container: container
        )

        XCTAssertTrue(try fetchAllCache().isEmpty)
    }

    // MARK: - Helpers

    private func fetchAllCache() throws -> [TodayEventCache] {
        try container.mainContext.fetch(FetchDescriptor<TodayEventCache>())
    }

    private func makeDozyEvent(
        title: String,
        startHour: Int = 9,
        endHour: Int = 10
    ) -> DozyEvent {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .hour, value: startHour, to: today)!
        let end = cal.date(byAdding: .hour, value: endHour, to: today)!
        return makeDozyEvent(title: title, startDate: start, endDate: end)
    }

    private func makeDozyEvent(title: String, startDate: Date, endDate: Date) -> DozyEvent {
        DozyEvent(
            title: title,
            startDate: startDate,
            endDate: endDate
        )
    }
}
