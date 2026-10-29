//
//  PushTests.swift
//  Dozy AITests
//
//  #95 공유 캘린더 푸시 — payload 해석 · 알림 문구 · 토큰 등록/해제 · 알림 카드 중복 방지.
//  iOS · macOS 테스트 타깃 공통 (실제 APNs · Supabase 는 건드리지 않는다).
//

import XCTest
import SwiftData
@testable import Dozy_AI

// MARK: - Payload

final class SharedEventPushTests: XCTestCase {

    private func userInfo(_ dozy: [String: Any]) -> [AnyHashable: Any] {
        ["aps": ["alert": ["loc-key": "x"]], "dozy": dozy]
    }

    private let valid: [String: Any] = [
        "type": "shared_event", "event_id": "e1", "calendar_id": "c1",
        "title": "치과", "sender": "민지", "start": "2026-10-29T09:00:00Z",
    ]

    func test_parsesSharedEventPush() {
        let push = SharedEventPush(userInfo: userInfo(valid))
        XCTAssertEqual(push?.eventID, "e1")
        XCTAssertEqual(push?.calendarID, "c1")
        XCTAssertEqual(push?.title, "치과")
        XCTAssertEqual(push?.senderName, "민지")
        XCTAssertEqual(push?.startDate, ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z"))
    }

    func test_parsesFractionalSecondsDate() {
        var dozy = valid
        dozy["start"] = "2026-10-29T09:00:00.000+00:00"
        XCTAssertEqual(SharedEventPush(userInfo: userInfo(dozy))?.startDate,
                       ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z"))
    }

    func test_emptySender_isNil() {
        var dozy = valid
        dozy["sender"] = ""
        XCTAssertNil(SharedEventPush(userInfo: userInfo(dozy))?.senderName)
        dozy["sender"] = NSNull()
        XCTAssertNil(SharedEventPush(userInfo: userInfo(dozy))?.senderName)
    }

    func test_rejectsOtherPayloads() {
        var wrongType = valid; wrongType["type"] = "reminder"
        var noID = valid; noID["event_id"] = ""
        var noTitle = valid; noTitle.removeValue(forKey: "title")
        XCTAssertNil(SharedEventPush(userInfo: userInfo(wrongType)))
        XCTAssertNil(SharedEventPush(userInfo: userInfo(noID)))
        XCTAssertNil(SharedEventPush(userInfo: userInfo(noTitle)))
        XCTAssertNil(SharedEventPush(userInfo: ["aps": ["alert": "hi"]]))
    }

    func test_cardBody_withAndWithoutSender() {
        XCTAssertEqual(SharedEventNotificationText.body(sender: "민지", title: "치과"),
                       String(localized: "\("민지")님이 '\("치과")' 일정을 공유했습니다"))
        XCTAssertEqual(SharedEventNotificationText.body(sender: nil, title: "치과"),
                       String(localized: "파트너님이 '\("치과")' 일정을 공유했습니다"))
        XCTAssertEqual(SharedEventNotificationText.body(sender: "", title: "치과"),
                       SharedEventNotificationText.body(sender: nil, title: "치과"))
    }

    /// 서버(send-push)가 보내는 loc-key 와 앱 문구 키가 같아야 배너가 번역된다
    func test_serverLocKeys_matchAppFormat() {
        XCTAssertEqual(SharedEventNotificationText.senderKey, "%@님이 '%@' 일정을 공유했습니다")
        XCTAssertEqual(SharedEventNotificationText.partnerKey, "파트너님이 '%@' 일정을 공유했습니다")
    }

    func test_hexToken() {
        XCTAssertEqual(PushSettings.hexString(from: Data([0x00, 0x0f, 0xab, 0xff])), "000fabff")
    }
}

// MARK: - 토큰 등록 · 해제

final class PushRegistrationUseCaseTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var service: MockPushTokenService!

    override func setUp() {
        super.setUp()
        suiteName = "PushRegistrationUseCaseTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        service = MockPushTokenService()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        service = nil
        super.tearDown()
    }

    private func makeUseCase() -> PushRegistrationUseCase {
        PushRegistrationUseCase(service: service, defaults: defaults, environment: "sandbox")
    }

    func test_sharedNotifications_defaultOn() {
        XCTAssertTrue(PushSettings.isSharedNotificationsEnabled(defaults: defaults))
    }

    func test_updateToken_storesAndRegisters_whenSignedIn() async {
        await makeUseCase().updateToken("abc")
        XCTAssertEqual(PushSettings.deviceToken(defaults: defaults), "abc")
        XCTAssertEqual(service.registered.map(\.token), ["abc"])
        XCTAssertEqual(service.registered.first?.environment, "sandbox")
        XCTAssertEqual(service.registered.first?.sharedEnabled, true)
    }

    func test_updateToken_onlyStores_whenSignedOut() async {
        service.signedIn = false
        await makeUseCase().updateToken("abc")
        XCTAssertEqual(PushSettings.deviceToken(defaults: defaults), "abc")
        XCTAssertTrue(service.registered.isEmpty)
    }

    func test_registerIfPossible_withoutToken_doesNothing() async {
        await makeUseCase().registerIfPossible()
        XCTAssertTrue(service.registered.isEmpty)
    }

    func test_unregister_removesStoredToken() async {
        PushSettings.setDeviceToken("abc", defaults: defaults)
        await makeUseCase().unregister()
        XCTAssertEqual(service.unregistered, ["abc"])
    }

    func test_setSharedNotificationsEnabled_persistsAndReRegisters() async {
        PushSettings.setDeviceToken("abc", defaults: defaults)
        await makeUseCase().setSharedNotificationsEnabled(false)
        XCTAssertFalse(PushSettings.isSharedNotificationsEnabled(defaults: defaults))
        XCTAssertEqual(service.registered.last?.sharedEnabled, false)
    }

    func test_registerFailure_doesNotThrow_andRecordsNonFatal() async {
        let crash = MockCrashReportingService()
        let previous = CrashReporting.current
        CrashReporting.current = crash
        defer { CrashReporting.current = previous }

        service.stubbedError = URLError(.notConnectedToInternet)
        PushSettings.setDeviceToken("abc", defaults: defaults)
        await makeUseCase().registerIfPossible()
        XCTAssertEqual(crash.recorded.map(\.context), ["push.register_token"])
    }
}

// MARK: - 알림 카드 중복 방지

@MainActor
final class SharedNotificationCardTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: Schema([NotificationRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    private func push(_ id: String) -> SharedEventPush {
        SharedEventPush(eventID: id, calendarID: "c1", title: "치과", senderName: "민지", startDate: nil)
    }

    func test_saveSharedIfNeeded_createsOnce_perEvent() throws {
        let repo = NotificationRepository(modelContainer: container)
        XCTAssertTrue(repo.saveSharedIfNeeded(push("e1")))
        XCTAssertFalse(repo.saveSharedIfNeeded(push("e1")))
        XCTAssertTrue(repo.saveSharedIfNeeded(push("e2")))

        let records = try container.mainContext.fetch(FetchDescriptor<NotificationRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.allSatisfy { $0.kind == "shared" && $0.senderName == "민지" })
        XCTAssertEqual(Set(records.map(\.body)), [SharedEventNotificationText.body(sender: "민지", title: "치과")])
    }

    func test_reminderRecordWithSameEventID_doesNotBlockSharedCard() throws {
        container.mainContext.insert(NotificationRecord(
            eventID: "e1", eventTitle: "치과", body: "곧 시작", deliveryDate: Date(), eventStartDate: Date()
        ))
        try container.mainContext.save()
        XCTAssertTrue(NotificationRepository(modelContainer: container).saveSharedIfNeeded(push("e1")))
    }
}
