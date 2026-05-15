//
//  CreateQuickEventIntentTests.swift
//  Dozy AITests
//
//  위젯 "+" 버튼이 실행하는 AppIntent 검증.
//  perform() 이 App Group UserDefaults 의 pendingCreateEvent 플래그를 set 하는지,
//  그리고 메인 앱이 이를 소비해 dozyWidgetOpenAddEvent 알림을 발화하는지 확인.
//
//  주의: 테스트 타겟엔 group.com.dozy-ai.shared App Group entitlement 가 없을 수
//  있으므로 cross-process 동작은 검증할 수 없다. 같은 프로세스 내 in-memory
//  UserDefaults suite 접근 (`UserDefaults(suiteName:)`) 은 동작하므로 그 수준에서
//  set/clear 동작만 확인한다.
//

import XCTest
@testable import Dozy_AI

final class CreateQuickEventIntentTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: CreateQuickEventIntent.appGroupID)
        // 이전 테스트 잔여 플래그 제거.
        defaults?.removeObject(forKey: CreateQuickEventIntent.pendingFlagKey)
    }

    override func tearDown() {
        defaults?.removeObject(forKey: CreateQuickEventIntent.pendingFlagKey)
        defaults = nil
        super.tearDown()
    }

    func test_perform_setsPendingFlag() async throws {
        XCTAssertFalse(
            defaults?.bool(forKey: CreateQuickEventIntent.pendingFlagKey) ?? false,
            "사전 조건: 플래그가 꺼져 있어야 함"
        )

        let intent = CreateQuickEventIntent()
        _ = try await intent.perform()

        XCTAssertTrue(
            defaults?.bool(forKey: CreateQuickEventIntent.pendingFlagKey) == true,
            "perform 후 pendingCreateEvent 가 true 여야 함"
        )
    }

    func test_perform_idempotent() async throws {
        // 한 번 더 호출해도 여전히 true (중복 호출이 토글로 false 가 되면 안 됨).
        let intent = CreateQuickEventIntent()
        _ = try await intent.perform()
        _ = try await intent.perform()

        XCTAssertTrue(
            defaults?.bool(forKey: CreateQuickEventIntent.pendingFlagKey) == true
        )
    }
}
