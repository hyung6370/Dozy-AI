//
//  AuthSheetDragLogicTests.swift
//  Dozy AITests
//
//  로그인 시트 드래그 클램프/스냅 규칙 검증.
//  좌표계: SwiftUI 는 아래로 갈수록 y 가 커진다 — 위로 드래그 = 음수 translation.
//

import XCTest
@testable import Dozy_AI

final class AuthSheetDragLogicTests: XCTestCase {

    /// AuthSheetView 와 동일한 임계값.
    private let logic = AuthSheetDragLogic(dragThreshold: 150)
    /// medium 시작 위치 예시값 (컨테이너 700pt × 0.42 ≈ 294 같은 상황을 단순화).
    private let start: CGFloat = 300

    // MARK: - clampedDragOffset (onChanged)

    func test_아래로_드래그는_클램프되지_않는다() {
        let clamped = logic.clampedDragOffset(translation: 220, startOffsetY: start, endingOffsetY: 0)
        XCTAssertEqual(clamped, 220)
    }

    func test_medium에서_위로는_펼침_위치까지만_끌린다() {
        // 한계 안쪽은 그대로 통과.
        XCTAssertEqual(
            logic.clampedDragOffset(translation: -200, startOffsetY: start, endingOffsetY: 0),
            -200
        )
        // 펼침 위치(-start)를 넘으면 -start 에서 잘린다.
        XCTAssertEqual(
            logic.clampedDragOffset(translation: -500, startOffsetY: start, endingOffsetY: 0),
            -start
        )
    }

    func test_펼친_상태에서는_위로_끌리지_않는다() {
        // ending = -start 이면 하한이 0 — 위로는 잠기고 아래로만 끌린다.
        XCTAssertEqual(
            logic.clampedDragOffset(translation: -50, startOffsetY: start, endingOffsetY: -start),
            0
        )
        XCTAssertEqual(
            logic.clampedDragOffset(translation: 80, startOffsetY: start, endingOffsetY: -start),
            80
        )
    }

    // MARK: - endAction (onEnded)

    func test_위로_임계값_이상_끌면_펼침() {
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: -151, endingOffsetY: 0, isLoading: false),
            .expand
        )
    }

    func test_임계값에_딱_걸치면_위치_유지() {
        // 경계값은 "충분히 끌었다" 로 치지 않는다 (strict 비교).
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: -150, endingOffsetY: 0, isLoading: false),
            .stay
        )
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: 150, endingOffsetY: 0, isLoading: false),
            .stay
        )
    }

    func test_짧은_드래그는_위치_유지() {
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: -80, endingOffsetY: 0, isLoading: false),
            .stay
        )
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: 80, endingOffsetY: -start, isLoading: false),
            .stay
        )
    }

    func test_펼친_상태에서_아래로_임계값_이상이면_medium_복귀() {
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: 151, endingOffsetY: -start, isLoading: false),
            .collapse
        )
    }

    func test_medium에서_아래로_임계값_이상이면_닫기() {
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: 151, endingOffsetY: 0, isLoading: false),
            .dismiss
        )
    }

    func test_로딩_중에는_닫기가_잠긴다() {
        // interactiveDismissDisabled 대응 — 로그인 요청 중 스와이프 닫기 방지.
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: 300, endingOffsetY: 0, isLoading: true),
            .stay
        )
    }

    func test_로딩_중에도_펼침과_복귀는_가능() {
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: -300, endingOffsetY: 0, isLoading: true),
            .expand
        )
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: 300, endingOffsetY: -start, isLoading: true),
            .collapse
        )
    }

    // MARK: - 회귀 방지 시나리오

    /// 빈틈 버그 회귀 방지 — 펼친 상태에서 어떤 translation 이 와도,
    /// 클램프를 거친 값으로는 시트가 위로 더 갈 수 있는 결정이 나오지 않는다.
    func test_펼친_상태에서는_클램프_때문에_다시_펼침_결정이_나올_수_없다() {
        for translation in stride(from: CGFloat(-600), through: 600, by: 37) {
            let clamped = logic.clampedDragOffset(
                translation: translation, startOffsetY: start, endingOffsetY: -start
            )
            XCTAssertGreaterThanOrEqual(clamped, 0, "펼친 상태의 클램프 하한은 0")

            let action = logic.endAction(
                currentDragOffsetY: clamped, endingOffsetY: -start, isLoading: false
            )
            XCTAssertNotEqual(action, .expand, "펼친 상태에서 재펼침은 불가")
            XCTAssertNotEqual(action, .dismiss, "펼친 상태에서 바로 닫기는 불가 (medium 을 거쳐야 함)")
        }
    }

    /// medium 에서 한계(-start)까지 끌어 놓으면 펼침으로 스냅된다.
    /// (start 가 threshold 보다 큰 일반적인 기기 크기 전제)
    func test_medium에서_한계까지_끌면_펼침으로_스냅된다() {
        let clamped = logic.clampedDragOffset(
            translation: -1000, startOffsetY: start, endingOffsetY: 0
        )
        XCTAssertEqual(clamped, -start)
        XCTAssertEqual(
            logic.endAction(currentDragOffsetY: clamped, endingOffsetY: 0, isLoading: false),
            .expand
        )
    }
}
