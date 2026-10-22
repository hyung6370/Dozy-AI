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

    /// 하위 화면으로 push 하면 탭바가 사라지고, 뒤로 가면 다시 나타나는지 확인
    @MainActor
    func test_pushSubScreen_hidesTabBar() throws {
        app.tabButton("tab_settings").tap()
        let themeRow = app.staticTexts["테마"].firstMatch
        XCTAssertTrue(themeRow.waitForExistence(timeout: 5), "설정 탭에 '테마' 행이 있어야 합니다")
        themeRow.tap()

        let homeTab = app.tabButton("tab_home")
        XCTAssertTrue(waitUntil(timeout: 3) { !homeTab.exists }, "하위 화면에서는 탭바가 숨겨져야 합니다")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3), "루트로 돌아오면 탭바가 다시 보여야 합니다")
    }

    /// 일정 생성 시트가 열리면 탭바가 사라지고, 닫히면 다시 나타나는지 확인
    @MainActor
    func test_createEventSheet_hidesTabBar() throws {
        app.createEventButton.tap()
        let homeTab = app.tabButton("tab_home")
        XCTAssertTrue(waitUntil(timeout: 3) { !homeTab.exists }, "일정 생성 시트가 열리면 탭바가 숨겨져야 합니다")

        app.navigationBars["새 일정"].buttons["취소"].tap()
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3), "시트를 닫으면 탭바가 다시 보여야 합니다")
    }

    /// 설정의 '로그인 · 회원가입' 커스텀 시트가 열리면 탭바가 사라지고, 닫히면 다시 나타나는지 확인
    @MainActor
    func test_settingsLoginSheet_hidesTabBar() throws {
        app.tabButton("tab_settings").tap()
        let loginRow = app.staticTexts["로그인 · 회원가입"].firstMatch
        guard loginRow.waitForExistence(timeout: 5) else {
            throw XCTSkip("로그인 상태라 '로그인 · 회원가입' 행이 없습니다")
        }
        loginRow.tap()

        let homeTab = app.tabButton("tab_home")
        XCTAssertTrue(waitUntil(timeout: 3) { !homeTab.exists }, "로그인 시트가 열리면 탭바가 숨겨져야 합니다")

        // 시트 바깥(상단 dim 영역) 탭 → 닫힘
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3), "로그인 시트를 닫으면 탭바가 다시 보여야 합니다")
    }

    /// 텍스트 필드를 눌러 키보드가 올라오면 탭바가 사라지고, 키보드가 내려가면 다시 나타나는지 확인
    @MainActor
    func test_keyboard_hidesTabBar() throws {
        // 홈은 캘린더/미리알림 권한 프롬프트가 떠 있는 동안 isLoading 이라 메모 입력란을 그리지 않는다.
        // 시스템 권한 알림이 오면 허용하고 넘어간다 (버튼 라벨은 OS 언어에 따라 다름).
        let monitor = addUIInterruptionMonitor(withDescription: "권한 알림") { alert in
            for label in ["모든 이벤트 접근 허용", "모든 미리 알림 접근 허용", "허용", "Allow Full Access", "Allow", "OK", "확인"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }
        app.swipeUp()   // 인터럽션 모니터는 앱과 상호작용할 때 발동한다

        // axis: .vertical TextField 는 UITextView 로 노출되므로 타입을 특정하지 않고 identifier 로 찾는다.
        let memoField = app.descendants(matching: .any).matching(identifier: "home_memo_field").firstMatch
        guard memoField.waitForExistence(timeout: 10) else {
            throw XCTSkip("홈 데이터 로딩이 끝나지 않아(권한 프롬프트 등) 메모 입력란이 표시되지 않음 — 실기기에서 확인")
        }
        if !memoField.isHittable { app.swipeUp() }   // 화면 아래쪽이라 스크롤로 끌어올린다
        memoField.tap()

        let homeTab = app.tabButton("tab_home")
        XCTAssertTrue(waitUntil(timeout: 3) { !homeTab.exists }, "키보드가 올라오면 탭바가 숨겨져야 합니다")

        // 여백(상단 인사말 영역) 탭 → 키보드 내려감 (dismissesKeyboardOnTap)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "입력란을 누르면 키보드가 올라와야 합니다")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.17)).tap()
        XCTAssertTrue(waitUntil(timeout: 3) { !app.keyboards.firstMatch.exists }, "여백을 누르면 키보드가 내려가야 합니다")
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "키보드가 내려가면 탭바가 다시 보여야 합니다")
    }

    /// 조건이 참이 될 때까지 폴링 (XCUIElement 의 비존재는 waitForExistence 로 못 기다린다).
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
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
