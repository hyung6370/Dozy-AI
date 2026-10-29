//
//  CrashReportingTests.swift
//  Dozy AITests
//
//  크래시 리포팅(#117) — 비치명 오류가 사용자 콘텐츠 없이 기록되는지, 정적 진입점이 꽂힌 구현으로 가는지,
//  설정 파일이 없을 때 Firebase 를 건드리지 않는지. iOS · macOS 테스트 타깃 공통.
//

import XCTest
@testable import Dozy_AI

final class CrashReportingTests: XCTestCase {

    private var previous: CrashReportingServiceProtocol!

    override func setUp() {
        super.setUp()
        previous = CrashReporting.current
    }

    override func tearDown() {
        CrashReporting.current = previous
        super.tearDown()
    }

    private struct ContentLeakingError: LocalizedError {
        var errorDescription: String? { "upsert failed for row title=비밀 병원 예약 notes=메모" }
    }

    func test_sanitized_dropsMessage_keepsClassification() {
        let original = NSError(domain: "PostgrestError", code: 409,
                               userInfo: [NSLocalizedDescriptionKey: "duplicate key: 비밀 병원 예약"])
        let sanitized = CrashReporting.sanitized(original, context: "sync.upload.dozy_events")

        XCTAssertEqual(sanitized.domain, "dozy.sync.upload.dozy_events")
        XCTAssertEqual(sanitized.code, 409)
        XCTAssertEqual(sanitized.userInfo["underlying_domain"] as? String, "PostgrestError")
        XCTAssertNotNil(sanitized.userInfo["error_type"] as? String)
        XCTAssertNil(sanitized.userInfo[NSLocalizedDescriptionKey])
        XCTAssertFalse(sanitized.localizedDescription.contains("비밀"))
    }

    func test_sanitized_swiftErrorDescription_isNotCarried() {
        let sanitized = CrashReporting.sanitized(ContentLeakingError(), context: "ai.summary.on_device_fallback")
        let everything = "\(sanitized.domain) \(sanitized.userInfo) \(sanitized.localizedDescription)"
        XCTAssertFalse(everything.contains("비밀"))
        XCTAssertFalse(everything.contains("메모"))
        XCTAssertEqual(sanitized.userInfo["error_type"] as? String, "ContentLeakingError")
    }

    func test_record_routesToCurrentReporter() {
        let mock = MockCrashReportingService()
        CrashReporting.current = mock
        CrashReporting.record(NSError(domain: "x", code: 1), context: "realtime.initial_fetch")
        XCTAssertEqual(mock.recorded.count, 1)
        XCTAssertEqual(mock.recorded.first?.context, "realtime.initial_fetch")
    }

    func test_defaultReporter_isNoop() {
        CrashReporting.current = NoopCrashReportingService()
        CrashReporting.record(NSError(domain: "x", code: 1), context: "any")   // 크래시 없이 무시
    }

    func test_firebaseService_withoutConfigFile_staysUnconfigured() {
        let service = FirebaseCrashReportingService(enabled: true, hasConfigFile: false)
        XCTAssertFalse(service.isConfigured)
        service.record(NSError(domain: "x", code: 1), context: "any")
        service.log("hello")
        service.setCollectionEnabled(false)
        XCTAssertFalse(service.isConfigured)
    }

    func test_bootstrap_withoutConfigFile_doesNotConfigure() {
        XCTAssertFalse(FirebaseBootstrap.configureIfAvailable(hasConfigFile: false))
    }

    func test_debugBuild_withoutDebugArguments_doesNotCollect() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if !args.contains("-FIRAnalyticsDebugEnabled") && !args.contains("-FIRDebugEnabled") {
            XCTAssertFalse(FirebaseBootstrap.buildAllowsCollection)
        }
        #endif
    }
}
