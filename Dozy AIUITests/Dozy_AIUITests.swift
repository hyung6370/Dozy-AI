//
//  Dozy_AIUITests.swift
//  Dozy AIUITests
//

import XCTest

// MARK: - 헬퍼

private extension XCUIApplication {
    /// 캘린더 탭의 '일정 추가' (+) 버튼
    /// ToolbarItem 버튼은 navigationBars 계층 또는 buttons 계층에서 찾음
    var calendarAddButton: XCUIElement {
        // identifier로 먼저 시도, 없으면 label로 폴백
        let byId = buttons.matching(identifier: "btn_calendar_add").firstMatch
        return byId.exists ? byId : buttons["일정 추가"]
    }
}

// MARK: - 탭 네비게이션 테스트

final class TabNavigationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 앱 실행 직후 탭바가 표시되는지 확인
    @MainActor
    func test_launch_tabBarIsVisible() throws {
        XCTAssertTrue(app.tabBars.firstMatch.exists, "탭바가 표시되어야 합니다")
    }

    /// 홈 탭이 기본으로 선택되어 있는지 확인
    @MainActor
    func test_launch_homeTabIsSelected() throws {
        let homeTab = app.tabBars.buttons["홈"]
        XCTAssertTrue(homeTab.exists, "홈 탭이 존재해야 합니다")
        XCTAssertTrue(homeTab.isSelected, "앱 실행 시 홈 탭이 선택되어 있어야 합니다")
    }

    /// 캘린더 탭 이동 시 캘린더 전용 버튼(일정 추가)이 표시되는지 확인
    @MainActor
    func test_tapCalendarTab_showsCalendarScreen() throws {
        // SwiftUI NavigationStack toolbar는 첫 방문 시 accessibility tree에 늦게 등록됨
        // → 한 번 방문 후 홈으로 돌아왔다가 재방문하면 즉시 인식됨
        app.tabBars.buttons["캘린더"].tap()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 2)
        app.tabBars.buttons["홈"].tap()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 1)
        app.tabBars.buttons["캘린더"].tap()
        let addBtn = app.buttons.matching(identifier: "btn_calendar_add").firstMatch
        XCTAssertTrue(
            addBtn.waitForExistence(timeout: 5),
            "캘린더 탭 선택 후 '일정 추가' 버튼이 표시되어야 합니다"
        )
    }

    /// 인사이트 탭 탭했을 때 화면이 크래시 없이 로드되는지 확인
    @MainActor
    func test_tapInsightsTab_loadsWithoutCrash() throws {
        app.tabBars.buttons["인사이트"].tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 3),
            "인사이트 탭 이동 후 앱이 정상 동작해야 합니다"
        )
    }

    /// 설정 탭 탭했을 때 화면이 크래시 없이 로드되는지 확인
    @MainActor
    func test_tapSettingsTab_loadsWithoutCrash() throws {
        app.tabBars.buttons["설정"].tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 3),
            "설정 탭 이동 후 앱이 정상 동작해야 합니다"
        )
    }

    /// 모든 탭을 순서대로 탐색해도 크래시가 없는지 확인
    @MainActor
    func test_navigateAllTabs_noCrash() throws {
        let tabs = ["홈", "캘린더", "인사이트", "설정"]
        for tab in tabs {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(
                app.tabBars.firstMatch.waitForExistence(timeout: 3),
                "\(tab) 탭 이동 후 앱이 살아있어야 합니다"
            )
        }
    }
}

// MARK: - 캘린더 이벤트 생성 플로우 테스트

final class CalendarEventCreationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // NavigationStack toolbar는 첫 방문 시 accessibility tree에 늦게 등록됨
        // → 한 번 방문 후 홈으로 돌아왔다가 재방문하면 즉시 인식됨
        app.tabBars.buttons["캘린더"].tap()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 2)
        app.tabBars.buttons["홈"].tap()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 1)
        app.tabBars.buttons["캘린더"].tap()
        let addBtn = app.buttons.matching(identifier: "btn_calendar_add").firstMatch
        guard addBtn.waitForExistence(timeout: 5) else {
            XCTFail("setUp: 캘린더 탭의 '일정 추가' 버튼이 표시되어야 합니다")
            return
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private var addButton: XCUIElement {
        app.buttons.matching(identifier: "btn_calendar_add").firstMatch
    }

    /// + 버튼 탭 시 새 일정 시트가 표시되는지 확인
    @MainActor
    func test_tapAddButton_showsNewEventSheet() throws {
        addButton.tap()
        XCTAssertTrue(
            app.navigationBars["새 일정"].waitForExistence(timeout: 3),
            "+ 버튼 탭 후 '새 일정' 시트가 표시되어야 합니다"
        )
    }

    /// 새 일정 시트에 제목 입력란이 존재하는지 확인
    @MainActor
    func test_newEventSheet_hasTitleField() throws {
        addButton.tap()
        XCTAssertTrue(app.navigationBars["새 일정"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.textFields["제목"].exists,
            "새 일정 시트에 제목 입력란이 있어야 합니다"
        )
    }

    /// 제목 미입력 시 저장 버튼이 비활성화되는지 확인
    @MainActor
    func test_newEventSheet_saveDisabledWithEmptyTitle() throws {
        addButton.tap()
        XCTAssertTrue(app.navigationBars["새 일정"].waitForExistence(timeout: 3))
        let saveButton = app.navigationBars["새 일정"].buttons["저장"]
        XCTAssertTrue(saveButton.exists, "저장 버튼이 존재해야 합니다")
        XCTAssertFalse(saveButton.isEnabled, "제목 미입력 시 저장 버튼이 비활성화되어야 합니다")
    }

    /// 제목 입력 후 저장 버튼이 활성화되는지 확인
    @MainActor
    func test_newEventSheet_saveEnabledAfterTypingTitle() throws {
        addButton.tap()
        XCTAssertTrue(app.navigationBars["새 일정"].waitForExistence(timeout: 3))
        app.textFields["제목"].tap()
        app.textFields["제목"].typeText("팀 미팅")
        let saveButton = app.navigationBars["새 일정"].buttons["저장"]
        XCTAssertTrue(saveButton.isEnabled, "제목 입력 후 저장 버튼이 활성화되어야 합니다")
    }

    /// 취소 버튼 탭 시 시트가 닫히는지 확인
    @MainActor
    func test_newEventSheet_cancelDismissesSheet() throws {
        addButton.tap()
        XCTAssertTrue(app.navigationBars["새 일정"].waitForExistence(timeout: 3))
        app.navigationBars["새 일정"].buttons["취소"].tap()
        let gone = !app.navigationBars["새 일정"].waitForExistence(timeout: 3)
        XCTAssertTrue(gone, "취소 후 새 일정 시트가 닫혀야 합니다")
    }

    /// 이벤트를 저장하고 캘린더로 돌아오는 플로우 확인
    @MainActor
    func test_createEvent_savesAndDismissesSheet() throws {
        addButton.tap()
        XCTAssertTrue(app.navigationBars["새 일정"].waitForExistence(timeout: 3))
        app.textFields["제목"].tap()
        app.textFields["제목"].typeText("UI 테스트 이벤트")
        app.navigationBars["새 일정"].buttons["저장"].tap()
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 3),
            "저장 후 캘린더 화면으로 돌아와야 합니다"
        )
    }
}

// MARK: - 앱 안정성 테스트

final class AppStabilityTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 앱 실행 후 홈 화면이 정상 로드되는지 확인
    @MainActor
    func test_launch_homeScreenLoadsSuccessfully() throws {
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 5),
            "앱 실행 후 탭바가 5초 내에 표시되어야 합니다"
        )
    }

    /// 캘린더 탭에서 홈으로 돌아올 수 있는지 확인
    @MainActor
    func test_calendarToHome_roundTrip() throws {
        // 첫 방문 후 홈으로 돌아왔다가 재방문 → toolbar accessibility 등록 대기
        app.tabBars.buttons["캘린더"].tap()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 2)
        app.tabBars.buttons["홈"].tap()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 1)
        app.tabBars.buttons["캘린더"].tap()
        let addBtn = app.buttons.matching(identifier: "btn_calendar_add").firstMatch
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "캘린더 탭의 '일정 추가' 버튼이 표시되어야 합니다")
        app.tabBars.buttons["홈"].tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 3),
            "홈 탭으로 돌아온 후 앱이 정상 동작해야 합니다"
        )
    }

    /// 여러 탭을 연속 전환해도 앱이 안정적으로 동작하는지 확인
    @MainActor
    func test_multipleTabSwitches_stayStable() throws {
        let sequence: [String] = ["설정", "인사이트", "캘린더", "홈", "캘린더"]
        for tab in sequence {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(
                app.tabBars.firstMatch.waitForExistence(timeout: 3),
                "\(tab) 탭 이동 후 앱이 정상 동작해야 합니다"
            )
        }
        let addBtn = app.buttons.matching(identifier: "btn_calendar_add").firstMatch
        XCTAssertTrue(
            addBtn.waitForExistence(timeout: 5),
            "캘린더 탭에서 '일정 추가' 버튼이 표시되어야 합니다"
        )
    }
}
