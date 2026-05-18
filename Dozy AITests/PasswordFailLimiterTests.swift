//
//  PasswordFailLimiterTests.swift
//  Dozy AITests
//
//  비밀번호 5회 실패 시 동작 검증.
//

import XCTest
@testable import Dozy_AI

final class PasswordFailLimiterTests: XCTestCase {

    // MARK: - Initial state

    func test_initial_count_is_zero_and_canSubmit_is_true() {
        let limiter = PasswordFailLimiter(threshold: 5)
        XCTAssertEqual(limiter.count, 0)
        XCTAssertTrue(limiter.canSubmit)
        XCTAssertFalse(limiter.hasReachedLimit)
        XCTAssertFalse(limiter.justReachedLimit)
    }

    // MARK: - recordFailure

    func test_recordFailure_increments_count() {
        var limiter = PasswordFailLimiter(threshold: 5)
        limiter.recordFailure()
        XCTAssertEqual(limiter.count, 1)
        limiter.recordFailure()
        XCTAssertEqual(limiter.count, 2)
    }

    func test_belowThreshold_canSubmit_stays_true() {
        var limiter = PasswordFailLimiter(threshold: 5)
        for _ in 0..<4 {
            limiter.recordFailure()
            XCTAssertTrue(limiter.canSubmit)
            XCTAssertFalse(limiter.hasReachedLimit)
            XCTAssertFalse(limiter.justReachedLimit)
        }
        XCTAssertEqual(limiter.count, 4)
    }

    // MARK: - justReachedLimit (alert 트리거)

    func test_justReachedLimit_true_only_at_exact_threshold() {
        var limiter = PasswordFailLimiter(threshold: 5)
        for i in 1...10 {
            limiter.recordFailure()
            if i == 5 {
                XCTAssertTrue(limiter.justReachedLimit, "5회째에 정확히 trigger 되어야 함")
            } else {
                XCTAssertFalse(limiter.justReachedLimit, "\(i)회째엔 trigger 되지 않아야 함")
            }
        }
    }

    // MARK: - At/Above threshold

    func test_atThreshold_canSubmit_becomes_false() {
        var limiter = PasswordFailLimiter(threshold: 5)
        for _ in 0..<5 { limiter.recordFailure() }
        XCTAssertEqual(limiter.count, 5)
        XCTAssertTrue(limiter.hasReachedLimit)
        XCTAssertFalse(limiter.canSubmit, "5회 도달 시 로그인 버튼 비활성")
    }

    func test_aboveThreshold_still_blocks_submit() {
        var limiter = PasswordFailLimiter(threshold: 5)
        for _ in 0..<7 { limiter.recordFailure() }
        XCTAssertEqual(limiter.count, 7)
        XCTAssertTrue(limiter.hasReachedLimit)
        XCTAssertFalse(limiter.canSubmit)
    }

    // MARK: - reset

    func test_reset_returns_to_initial_state() {
        var limiter = PasswordFailLimiter(threshold: 5)
        for _ in 0..<5 { limiter.recordFailure() }
        XCTAssertFalse(limiter.canSubmit)

        limiter.reset()
        XCTAssertEqual(limiter.count, 0)
        XCTAssertTrue(limiter.canSubmit)
        XCTAssertFalse(limiter.hasReachedLimit)
    }

    func test_reset_after_partial_failures() {
        var limiter = PasswordFailLimiter(threshold: 5)
        limiter.recordFailure()
        limiter.recordFailure()
        XCTAssertEqual(limiter.count, 2)
        limiter.reset()
        XCTAssertEqual(limiter.count, 0)
    }

    // MARK: - Full flow scenario

    func test_full_scenario_login_email_change_and_success() {
        var limiter = PasswordFailLimiter(threshold: 5)

        // 사용자가 비번 4번 틀림
        for _ in 0..<4 { limiter.recordFailure() }
        XCTAssertEqual(limiter.count, 4)
        XCTAssertTrue(limiter.canSubmit)

        // 이메일 필드를 바꿔서 reset
        limiter.reset()
        XCTAssertEqual(limiter.count, 0)

        // 다른 이메일로 다시 5번 틀림 → limit 도달
        for _ in 0..<5 { limiter.recordFailure() }
        XCTAssertFalse(limiter.canSubmit)
        XCTAssertTrue(limiter.justReachedLimit)

        // 비번 재설정 후 로그인 성공 → reset
        limiter.reset()
        XCTAssertTrue(limiter.canSubmit)
    }

    // MARK: - Different threshold

    func test_threshold_3_works_the_same() {
        var limiter = PasswordFailLimiter(threshold: 3)
        limiter.recordFailure()
        limiter.recordFailure()
        XCTAssertTrue(limiter.canSubmit)

        limiter.recordFailure()  // 3회
        XCTAssertFalse(limiter.canSubmit)
        XCTAssertTrue(limiter.justReachedLimit)
    }
}
