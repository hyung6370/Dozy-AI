//
//  Dozy_AIUITests.swift
//  Dozy AIUITests
//

import XCTest

// MARK: - 헬퍼

private extension XCUIApplication {
    /// 일정 생성 버튼. 캘린더 화면 툴바가 아니라 탭바 중앙의 액션 버튼이라
    /// 어느 탭에 있든 항상 노출된다.
    var createEventButton: XCUIElement {
        buttons["btn_create_event"]
    }

    /// 커스텀 탭바 (DozyMainTabBar)의 탭 버튼. 네이티브 UITabBar가 아니라 일반 Button
    func tabButton(_ id: String) -> XCUIElement {
        buttons[id]
    }
    
    /// 인트로 애니메이션(약 3.1초)이 끝나고 탭바가 노출될 때까지 대기
    @discardableResult
    func waitForTabBar(timeout: TimeInterval = 10) -> Bool {
        buttons["tab_home"].waitForExistence(timeout: timeout)
    }
}

// MARK: - 탭 네비게이션 테스트

final class TabNavigationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // DEBUG 빌드의 환경 선택 다이얼로그와 인트로 애니메이션을 건너뛴다.
        app.launchArguments += ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.waitForTabBar(), "인트로 종료 후 탭바가 표시되어야 합니다")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 앱 실행 직후 탭바가 표시되는지 확인
    @MainActor
    func test_launch_tabBarIsVisible() throws {
        XCTAssertTrue(app.buttons["tab_home"].exists, "탭바가 표시되어야 합니다")
    }

    /// 홈 탭이 기본으로 선택되어 있는지 확인
    @MainActor
    func test_launch_homeTabIsSelected() throws {
        let homeTab = app.tabButton("tab_home")
        XCTAssertTrue(homeTab.exists, "홈 탭이 존재해야 합니다")
        XCTAssertTrue(homeTab.isSelected, "앱 실행 시 홈 탭이 선택되어 있어야 합니다")
    }

    /// 캘린더 탭으로 이동하면 해당 탭이 선택 상태가 되는지 확인
    @MainActor
    func test_tapCalendarTab_showsCalendarScreen() throws {
        let calendarTab = app.tabButton("tab_calendar")
        calendarTab.tap()
        XCTAssertTrue(
            calendarTab.isSelected,
            "캘린더 탭을 탭하면 선택 상태가 되어야 합니다"
        )
        XCTAssertFalse(
            app.tabButton("tab_home").isSelected,
            "캘린더로 이동하면 홈 탭은 선택 해제되어야 합니다"
        )
    }

    /// 인사이트 탭 탭했을 때 화면이 크래시 없이 로드되는지 확인
    @MainActor
    func test_tapInsightsTab_loadsWithoutCrash() throws {
        app.tabButton("tab_insight").tap()
        XCTAssertTrue(
            app.tabButton("tab_home").waitForExistence(timeout: 3),
            "인사이트 탭 이동 후 앱이 정상 동작해야 합니다"
        )
    }

    /// 설정 탭 탭했을 때 화면이 크래시 없이 로드되는지 확인
    @MainActor
    func test_tapSettingsTab_loadsWithoutCrash() throws {
        app.tabButton("tab_settings").tap()
        XCTAssertTrue(
            app.tabButton("tab_home").waitForExistence(timeout: 3),
            "설정 탭 이동 후 앱이 정상 동작해야 합니다"
        )
    }

    /// 모든 탭을 순서대로 탐색해도 크래시가 없는지 확인
    @MainActor
    func test_navigateAllTabs_noCrash() throws {
        let tabs = ["tab_home", "tab_calendar", "tab_insight", "tab_settings"]
        for tab in tabs {
            app.tabButton(tab).tap()
            XCTAssertTrue(
                app.tabButton("tab_home").waitForExistence(timeout: 3),
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
        // DEBUG 빌드의 환경 선택 다이얼로그와 인트로 애니메이션을 건너뛴다.
        app.launchArguments += ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.waitForTabBar(), "인트로 종료 후 탭바가 표시되어야 합니다")
        // 일정 생성 버튼은 탭바 중앙에 있어 탭 이동 없이 바로 사용 가능.
        guard app.createEventButton.waitForExistence(timeout: 5) else {
            XCTFail("setUp: 탭바의 일정 생성 버튼이 표시되어야 합니다")
            return
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private var addButton: XCUIElement {
        app.createEventButton
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
        // DEBUG 빌드의 환경 선택 다이얼로그와 인트로 애니메이션을 건너뛴다.
        app.launchArguments += ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.waitForTabBar(), "인트로 종료 후 탭바가 표시되어야 합니다")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 앱 실행 후 홈 화면이 정상 로드되는지 확인.
    /// setUp 이 탭바 노출까지 이미 대기하므로, 여기서는 홈 탭이 선택된 채
    /// 실제로 조작 가능한 상태인지(hittable) 까지 확인한다.
    @MainActor
    func test_launch_homeScreenLoadsSuccessfully() throws {
        let homeTab = app.tabButton("tab_home")
        XCTAssertTrue(homeTab.isSelected, "앱 실행 후 홈 탭이 선택되어 있어야 합니다")
        XCTAssertTrue(homeTab.isHittable, "홈 탭이 조작 가능한 상태여야 합니다")
    }

    /// 캘린더 탭에서 홈으로 돌아올 수 있는지 확인
    @MainActor
    func test_calendarToHome_roundTrip() throws {
        let calendarTab = app.tabButton("tab_calendar")
        let homeTab = app.tabButton("tab_home")

        calendarTab.tap()
        XCTAssertTrue(calendarTab.isSelected, "캘린더 탭이 선택되어야 합니다")

        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected, "홈 탭으로 돌아오면 홈이 선택되어야 합니다")
        XCTAssertTrue(homeTab.isHittable, "홈 복귀 후에도 탭바가 조작 가능해야 합니다")
    }

    /// 여러 탭을 연속 전환해도 앱이 안정적으로 동작하는지 확인
    @MainActor
    func test_multipleTabSwitches_stayStable() throws {
        let sequence: [String] = ["tab_settings", "tab_insight", "tab_calendar", "tab_home", "tab_calendar"]
        for tab in sequence {
            let button = app.tabButton(tab)
            button.tap()
            XCTAssertTrue(
                button.isSelected,
                "\(tab) 탭 이동 후 해당 탭이 선택되어야 합니다"
            )
        }
        XCTAssertTrue(
            app.createEventButton.isHittable,
            "연속 탭 전환 후에도 일정 생성 버튼이 조작 가능해야 합니다"
        )
    }
}
