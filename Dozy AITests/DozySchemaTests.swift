//
//  DozySchemaTests.swift
//  Dozy AITests
//
//  같은 store 파일을 두 컨테이너(앱 · 위젯)가 열어도 메모 저장이 깨지지 않는지 확인한다.
//  예전에는 위젯 · 인텐트가 부분 스키마로 열어 WorkLog 테이블이 지워지고 앱 저장이 실패했다.
//

import XCTest
import SwiftData
@testable import Dozy_AI

@MainActor
final class DozySchemaTests: XCTestCase {

    private var storeURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DozySchemaTests-\(UUID().uuidString)")
            .appendingPathComponent("default.store")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        storeURL = nil
        try await super.tearDown()
    }

    private func openContainer() throws -> ModelContainer {
        let schema = DozySchema.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
    }

    func test_secondContainerOnSameStore_keepsWorkLogSavable() throws {
        let app = try openContainer()
        let log = WorkLog(date: Date())
        log.addMemo("첫 메모")
        app.mainContext.insert(log)
        try app.mainContext.save()

        // 위젯 · 인텐트가 같은 파일을 연다
        let widget = try openContainer()
        XCTAssertEqual(try widget.mainContext.fetchCount(FetchDescriptor<TodayEventCache>()), 0)

        // 앱이 열어 둔 컨테이너로 다시 저장 — 부분 스키마였다면 여기서 SQLite 오류
        log.addMemo("두 번째 메모")
        XCTAssertNoThrow(try app.mainContext.save())
        XCTAssertEqual(try widget.mainContext.fetch(FetchDescriptor<WorkLog>()).first?.memos.count, 2)
    }

    func test_schemaCoversAllPersistedModels() {
        let names = Set(DozySchema.models.map { String(describing: $0) })
        XCTAssertEqual(names, [
            "WorkLog", "UserPattern", "DozyEvent", "EventCompletion",
            "NotificationRecord", "EventDisplaySettings", "UserCategory", "TodayEventCache"
        ])
    }
}
