//
//  RecurrenceInputUITests.swift
//  Dozy AIUITests
//
//  반복 일정 입력 (#147) — 새 일정 시트에서 반복을 고르면 기본이 "계속"이고, 날짜 지정 · 규칙별 요일 표시 ·
//  요약 문구가 맞는지, 저장한 일정의 상세 화면이 요약을 보여 주는지 확인한다. 끝나면 만든 일정을 지운다.
//  단계마다 스크린샷을 결과 번들에 남긴다 (실기기 확인용).
//
//  실행: 서명된 빌드여야 한다 (App Group). 시뮬레이터 · 실기기 모두
//    xcodebuild ... -allowProvisioningUpdates test -only-testing:'Dozy AIUITests/RecurrenceInputUITests'
//

import XCTest

final class RecurrenceInputUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.buttons["tab_home"].waitForExistence(timeout: 15), "탭바가 표시되어야 합니다")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 화면 밖이면 위로 쓸어 올려 보이게 한다.
    @discardableResult
    private func reveal(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        return element.exists && element.isHittable
    }

    private func menuItem(beginningWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func staticText(containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private var summary: XCUIElement { app.staticTexts["text_recurrence_summary"] }

    /// 로그인 상태인지 — 로그아웃이면 Dozy 일정 조회가 비어 저장한 일정이 화면에 안 보인다
    /// (`DozyEventRepository.filterByCurrentAccount`). 설정 탭의 로그인 행으로 판단한다.
    private func isLoggedIn() -> Bool {
        app.buttons["tab_settings"].tap()
        let loginRow = app.staticTexts["로그인 · 회원가입"]
        let loggedOut = loginRow.waitForExistence(timeout: 3)
        app.buttons["tab_home"].tap()
        return !loggedOut
    }

    /// 새 일정 시트를 열고 제목을 넣는다.
    private func openNewEvent(title: String) {
        app.buttons["btn_create_event"].tap()
        XCTAssertTrue(app.navigationBars["새 일정"].waitForExistence(timeout: 5))
        let titleField = app.textFields["제목"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText(title)
        app.navigationBars["새 일정"].tap()   // 키보드 내림
    }

    private func chooseRule(_ prefix: String) {
        let ruleMenu = app.buttons["menu_recurrence"]
        XCTAssertTrue(reveal(ruleMenu), "반복 메뉴가 보여야 합니다")
        ruleMenu.tap()
        let item = prefix == "매일" ? app.buttons["매일"] : menuItem(beginningWith: prefix)
        XCTAssertTrue(item.waitForExistence(timeout: 3), "반복 메뉴에 \(prefix) 항목이 있어야 합니다")
        item.tap()
    }

    private func chooseEnd(_ title: String) {
        let endMenu = app.buttons["menu_recurrence_end"]
        XCTAssertTrue(reveal(endMenu), "반복 종료 메뉴가 보여야 합니다")
        endMenu.tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.tap()
    }

    // MARK: - Tests

    /// 폼 동작 — 로그인 없이 돈다. 저장하지 않고 취소한다.
    @MainActor
    func test_recurrenceForm_defaultsToNoEnd_dateOption_summary() throws {
        openNewEvent(title: "반복 폼 확인")

        // 반복 메뉴: 매주 · 매월 항목에 시작일 정보
        let ruleMenu = app.buttons["menu_recurrence"]
        XCTAssertTrue(reveal(ruleMenu))
        ruleMenu.tap()
        XCTAssertTrue(app.buttons["매일"].waitForExistence(timeout: 3))
        XCTAssertTrue(menuItem(beginningWith: "매주 (").exists, "매주 항목에 요일이 붙어야 합니다")
        XCTAssertTrue(menuItem(beginningWith: "매월 (").exists, "매월 항목에 날짜가 붙어야 합니다")
        snapshot("1 반복 메뉴")
        app.buttons["매일"].tap()

        // 기본은 계속 반복
        let endMenu = app.buttons["menu_recurrence_end"]
        XCTAssertTrue(endMenu.waitForExistence(timeout: 3))
        XCTAssertTrue(endMenu.label.contains("안 함"), "반복 종료 기본값은 '안 함' 이어야 합니다: \(endMenu.label)")
        XCTAssertFalse(app.datePickers["picker_recurrence_end_date"].exists, "계속 반복이면 종료일 선택기가 없어야 합니다")
        reveal(summary)
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertTrue(summary.label.contains("계속"), "요약에 '계속' 이 있어야 합니다: \(summary.label)")
        snapshot("2 매일 · 계속")

        // 날짜 지정 → 종료일 선택기 + 요약에 "까지"
        chooseEnd("날짜 지정")
        XCTAssertTrue(app.datePickers["picker_recurrence_end_date"].waitForExistence(timeout: 3), "종료일 선택기가 보여야 합니다")
        reveal(summary)
        XCTAssertTrue(summary.label.contains("까지"), "요약에 종료일이 보여야 합니다: \(summary.label)")
        snapshot("3 날짜 지정")

        // 매주로 바꾸면 요약에 요일, 다시 안 함이면 계속
        chooseRule("매주 (")
        reveal(summary)
        XCTAssertTrue(summary.label.contains("요일"), "매주 요약에 요일이 보여야 합니다: \(summary.label)")
        chooseEnd("안 함")
        reveal(summary)
        XCTAssertTrue(summary.label.contains("계속"))
        XCTAssertFalse(app.datePickers["picker_recurrence_end_date"].exists)
        snapshot("4 매주 · 계속")

        // 반복 없음이면 요약 · 반복 종료가 사라진다
        chooseRule("없음")
        XCTAssertFalse(app.buttons["menu_recurrence_end"].waitForExistence(timeout: 1))
        XCTAssertFalse(summary.exists)

        app.navigationBars["새 일정"].buttons["취소"].tap()
    }

    /// 저장 → 캘린더 → 상세 반복 행 → 삭제 토스트. 로그인 상태에서만 돈다
    /// (로그아웃이면 Dozy 일정이 화면에 안 나온다).
    @MainActor
    func test_recurringEvent_save_showsSummaryInDetail_thenDelete() throws {
        guard isLoggedIn() else {
            throw XCTSkip("로그아웃 상태 — 저장한 Dozy 일정이 화면에 보이지 않아 건너뛴다")
        }
        let title = "반복UI \(Int(Date().timeIntervalSince1970) % 100_000)"
        openNewEvent(title: title)
        chooseRule("매주 (")
        reveal(summary)
        XCTAssertTrue(summary.label.contains("계속"))
        app.navigationBars["새 일정"].buttons["저장"].tap()
        XCTAssertFalse(app.navigationBars["새 일정"].waitForExistence(timeout: 2), "저장 후 시트가 닫혀야 합니다")

        // 캘린더 탭 — 오늘 일정 목록의 행을 연다 (월 그리드 막대가 아니라 마지막 일치가 목록)
        app.buttons["tab_calendar"].tap()
        let rows = app.staticTexts.matching(identifier: title)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8), "저장한 일정이 캘린더에 보여야 합니다")
        let target = rows.element(boundBy: max(0, rows.count - 1))
        reveal(target)
        target.tap()
        XCTAssertTrue(staticText(containing: "계속").waitForExistence(timeout: 5), "상세 화면 반복 행이 요약 문구여야 합니다")
        XCTAssertTrue(staticText(containing: "요일").exists, "상세 반복 행에 요일이 보여야 합니다")
        snapshot("5 상세 반복 요약")

        // 정리 — 모든 반복 일정 삭제 → 삭제 토스트 (#143)
        let delete = app.buttons["삭제"].firstMatch
        XCTAssertTrue(reveal(delete), "상세 화면에 삭제 버튼이 있어야 합니다")
        delete.tap()
        let deleteAll = app.buttons["모든 반복 일정 삭제"]
        XCTAssertTrue(deleteAll.waitForExistence(timeout: 3))
        deleteAll.tap()
        // 캘린더는 삭제 확인 알림창을 한 번 더 띄운다
        let confirm = app.alerts.buttons["삭제"]
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        XCTAssertTrue(staticText(containing: "일정을 삭제했어요").waitForExistence(timeout: 5), "삭제 토스트가 보여야 합니다")
        snapshot("6 삭제 토스트")
    }
}
