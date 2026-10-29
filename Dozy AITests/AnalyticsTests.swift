//
//  AnalyticsTests.swift
//  Dozy AITests
//
//  애널리틱스(#90) — 이벤트 이름 · 파라미터 규칙과, UseCase 가 성공했을 때만 올바른 이벤트를 1회 보내는지.
//  iOS · macOS 테스트 타깃 공통. Firebase 는 건드리지 않는다(MockAnalyticsService).
//

import XCTest
import Combine
@testable import Dozy_AI

// MARK: - AnalyticsEvent 규칙

final class AnalyticsEventTests: XCTestCase {

    /// 모든 case 를 한 번씩 — 새 case 를 추가하면 여기에도 넣어 규칙 검사를 받게 한다.
    private let allEvents: [AnalyticsEvent] = [
        .appOpened,
        .summaryGenerated(engine: .onDevice),
        .summarySheetOpened(source: .home),
        .eventCreated(method: .naturalLanguage),
        .sharedCalendarCreated,
        .sharedCalendarJoined(via: .link),
        .externalEventMirrored(provider: .google),
        .calendarSourceConnected(provider: .apple),
        .insightsOpened(periodDays: 30),
        .searchQuery(kind: .aggregate, engine: .onDevice),
    ]

    /// Firebase: 글자로 시작, 영문 소문자 · 숫자 · 밑줄, 40자 이하.
    private func isValidFirebaseName(_ name: String) -> Bool {
        name.range(of: "^[a-z][a-z0-9_]{0,39}$", options: .regularExpression) != nil
    }

    func test_eventNames_followFirebaseRules() {
        for event in allEvents {
            XCTAssertTrue(isValidFirebaseName(event.name), "잘못된 이벤트 이름: \(event.name)")
        }
    }

    func test_eventNames_areUnique() {
        let names = allEvents.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func test_parameterKeys_followFirebaseRules_andAtMost25() {
        for event in allEvents {
            XCTAssertLessThanOrEqual(event.parameters.count, 25)
            for key in event.parameters.keys {
                XCTAssertTrue(isValidFirebaseName(key), "\(event.name) 의 잘못된 파라미터 키: \(key)")
            }
        }
    }

    func test_reservedFirebaseEventNames_areNotUsed() {
        let reserved: Set<String> = ["app_open", "first_open", "session_start", "user_engagement",
                                     "app_update", "app_remove", "in_app_purchase", "screen_view", "error"]
        XCTAssertTrue(Set(allEvents.map(\.name)).isDisjoint(with: reserved))
    }

    func test_userPropertyNames_atMost24() {
        for property in AnalyticsUserProperty.allCases {
            XCTAssertLessThanOrEqual(property.rawValue.count, 24)
            XCTAssertTrue(isValidFirebaseName(property.rawValue))
        }
    }

    func test_parameters_carryOnlyEnumValuesOrInts() {
        XCTAssertEqual(AnalyticsEvent.eventCreated(method: .voice).parameters, ["method": .string("voice")])
        XCTAssertEqual(AnalyticsEvent.sharedCalendarJoined(via: .code).parameters, ["via": .string("code")])
        XCTAssertEqual(AnalyticsEvent.summarySheetOpened(source: .notification).parameters, ["source": .string("notification")])
        XCTAssertEqual(AnalyticsEvent.externalEventMirrored(provider: .apple).parameters, ["provider": .string("apple")])
        XCTAssertEqual(AnalyticsEvent.insightsOpened(periodDays: 90).parameters, ["period_days": .int(90)])
        XCTAssertTrue(AnalyticsEvent.appOpened.parameters.isEmpty)
    }

    func test_engineValue_groupsIntoThreeBuckets() {
        XCTAssertEqual(AnalyticsEvent.engineValue(.onDevice), "on_device")
        XCTAssertEqual(AnalyticsEvent.engineValue(.onDeviceFailed), "on_device_failed")
        for status in [AIEngineStatus.deviceNotEligible, .appleIntelligenceOff, .modelNotReady, .unavailable] {
            XCTAssertEqual(AnalyticsEvent.engineValue(status), "local")
        }
    }

    func test_inputMethodRawValues_areStableForDashboards() {
        XCTAssertEqual(EventInputMethod.allCases.map(\.rawValue),
                       ["manual", "natural_language", "voice", "menubar", "widget"])
    }

    func test_firebaseParameters_mapsIntsToNumbers_andEmptyToNil() {
        XCTAssertNil(FirebaseAnalyticsService.firebaseParameters([:]))
        let mapped = FirebaseAnalyticsService.firebaseParameters(["period_days": .int(7), "via": .string("code")])
        XCTAssertEqual(mapped?["period_days"] as? NSNumber, NSNumber(value: 7))
        XCTAssertEqual(mapped?["via"] as? String, "code")
    }
}

// MARK: - 수집 동의 설정

final class AnalyticsSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "AnalyticsSettingsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func test_defaultsToEnabled() {
        XCTAssertTrue(AnalyticsSettings.isEnabled(defaults: defaults))
    }

    func test_respectsUserChoice() {
        AnalyticsSettings.setEnabled(false, defaults: defaults)
        XCTAssertFalse(AnalyticsSettings.isEnabled(defaults: defaults))
        AnalyticsSettings.setEnabled(true, defaults: defaults)
        XCTAssertTrue(AnalyticsSettings.isEnabled(defaults: defaults))
    }

    /// 설정 파일이 없는 빌드(포크 저장소 · plist 준비 전)에서도 FirebaseApp.configure() 를 부르지 않고
    /// (크래시 없이) 모든 호출을 무시해야 한다.
    func test_firebaseService_withoutConfigFile_staysUnconfiguredAndIgnoresCalls() {
        let service = FirebaseAnalyticsService(enabled: true, hasConfigFile: false)
        XCTAssertFalse(service.isConfigured)
        service.track(.appOpened)
        service.setUserProperty("2", for: .calendarSourceCount)
        service.setCollectionEnabled(false)
        XCTAssertFalse(service.isConfigured)
    }

    func test_noopService_acceptsAllCalls() {
        let service = NoopAnalyticsService()
        service.track(.appOpened)
        service.setUserProperty("1", for: .calendarSourceCount)
        service.setCollectionEnabled(false)
    }
}

// MARK: - UseCase 가 보내는 이벤트

final class AnalyticsUseCaseTrackingTests: XCTestCase {

    private var analytics: MockAnalyticsService!
    private let baseDate = Date(timeIntervalSince1970: 1_775_000_000)

    override func setUp() {
        super.setUp()
        analytics = MockAnalyticsService()
    }

    // CreateDozyEventUseCase

    func test_createEvent_tracksEventCreatedOnceWithMethod() throws {
        let useCase = CreateDozyEventUseCase(repository: MockDozyEventRepository(), analytics: analytics)
        let event = DozyEvent(title: "치과", startDate: baseDate, endDate: baseDate)
        try awaitPublisher(useCase.execute(event, method: .naturalLanguage))
        XCTAssertEqual(analytics.trackedEvents, [.eventCreated(method: .naturalLanguage)])
    }

    func test_createEvent_defaultsToManual() throws {
        let useCase = CreateDozyEventUseCase(repository: MockDozyEventRepository(), analytics: analytics)
        try awaitPublisher(useCase.execute(DozyEvent(title: "a", startDate: baseDate, endDate: baseDate)))
        XCTAssertEqual(analytics.trackedEvents, [.eventCreated(method: .manual)])
    }

    func test_createEvent_whenSaveFails_tracksNothing() {
        let repo = MockDozyEventRepository()
        repo.stubbedSaveError = .unknown(underlying: NSError(domain: "test", code: 1))
        let useCase = CreateDozyEventUseCase(repository: repo, analytics: analytics)
        XCTAssertThrowsError(try awaitPublisher(useCase.execute(DozyEvent(title: "a", startDate: baseDate, endDate: baseDate))))
        XCTAssertTrue(analytics.trackedEvents.isEmpty)
    }

    func test_createEvent_doesNotLeakEventContent() throws {
        let useCase = CreateDozyEventUseCase(repository: MockDozyEventRepository(), analytics: analytics)
        let secret = "비밀 병원 예약"
        try awaitPublisher(useCase.execute(DozyEvent(title: secret, startDate: baseDate, endDate: baseDate,
                                                     location: "강남", notes: "메모"), method: .manual))
        for event in analytics.trackedEvents {
            for value in event.parameters.values {
                if case .string(let s) = value { XCTAssertFalse(s.contains(secret)) }
            }
        }
    }

    // GenerateDailySummaryUseCase

    func test_summary_tracksEngineFromAIService() throws {
        let ai = MockAIService()
        ai.stubbedSummary = makeTestSummary()
        ai.stubbedEngineStatus = .onDevice
        let useCase = GenerateDailySummaryUseCase(aiService: ai, repository: MockWorkLogRepository(), analytics: analytics)
        try awaitPublisher(useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: []))
        XCTAssertEqual(analytics.trackedEvents, [.summaryGenerated(engine: .onDevice)])
    }

    func test_summary_backgroundGeneration_isNotTracked() throws {
        let ai = MockAIService()
        ai.stubbedSummary = makeTestSummary()
        let useCase = GenerateDailySummaryUseCase(aiService: ai, repository: MockWorkLogRepository(), analytics: analytics)
        try awaitPublisher(useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [], tracksEvent: false))
        XCTAssertTrue(analytics.trackedEvents.isEmpty)
    }

    func test_summary_whenAIFails_tracksNothing() {
        let ai = MockAIService()
        ai.stubbedError = NSError(domain: "test", code: 1)
        let useCase = GenerateDailySummaryUseCase(aiService: ai, repository: MockWorkLogRepository(), analytics: analytics)
        XCTAssertThrowsError(try awaitPublisher(useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [])))
        XCTAssertTrue(analytics.trackedEvents.isEmpty)
    }

    // 공유 캘린더

    func test_createSharedCalendar_tracksCreated() throws {
        let useCase = CreateSharedCalendarUseCase(service: MockSharedCalendarService(), analytics: analytics)
        try awaitPublisher(useCase.execute(name: "우리"))
        XCTAssertEqual(analytics.trackedEvents, [.sharedCalendarCreated])
    }

    func test_joinSharedCalendar_tracksVia() throws {
        let useCase = JoinSharedCalendarUseCase(service: MockSharedCalendarService(), analytics: analytics)
        try awaitPublisher(useCase.execute(inviteCode: "ABC123", via: .link))
        try awaitPublisher(useCase.execute(inviteCode: "ABC123"))
        XCTAssertEqual(analytics.trackedEvents, [.sharedCalendarJoined(via: .link), .sharedCalendarJoined(via: .code)])
    }

    func test_joinSharedCalendar_whenFails_tracksNothing() {
        let service = MockSharedCalendarService()
        service.stubbedError = .unknown(underlying: NSError(domain: "test", code: 1))
        let useCase = JoinSharedCalendarUseCase(service: service, analytics: analytics)
        XCTAssertThrowsError(try awaitPublisher(useCase.execute(inviteCode: "BAD")))
        XCTAssertTrue(analytics.trackedEvents.isEmpty)
    }

    // 외부 일정 미러

    func test_mirror_tracksProviderOfOrigin() throws {
        let useCase = MirrorExternalEventUseCase(repository: MockDozyEventRepository(), analytics: analytics)
        try awaitPublisher(useCase.execute(makeTestEvent(source: .google), to: "cal-1"))
        XCTAssertEqual(analytics.trackedEvents, [.externalEventMirrored(provider: .google)])
    }
}
