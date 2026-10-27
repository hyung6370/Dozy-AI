//
//  Constants.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation

extension Notification.Name {
    static let dozyDataSyncCompleted = Notification.Name("dozy.dataSyncCompleted")
    static let dozyRequestNewEvent = Notification.Name("dozy.requestNewEvent")
    static let dozyRequestRefresh = Notification.Name("dozy.requestRefresh")
    static let dozyRequestGoToToday = Notification.Name("dozy.requestGoToToday")
    static let dozyRequestPreviousPeriod = Notification.Name("dozy.requestPreviousPeriod")
    static let dozyRequestNextPeriod = Notification.Name("dozy.requestNextPeriod")
    static let dozyRequestSummary = Notification.Name("dozy.requestSummary")
    static let googleSignInRestored = Notification.Name("dozy.googleSignInRestored")
    static let dozyEventChanged = Notification.Name("dozy.eventChanged")
    /// 일정이 생성·삭제됨 — completion 토글이 아니라 리스트 자체가 바뀐 경우.
    /// 듣는 쪽은 todayEvents / 캘린더 범위를 통째로 다시 로드해야 한다.
    static let dozyEventListChanged = Notification.Name("dozy.eventListChanged")
    /// 공유 캘린더 목록이 바뀜 — create/join/leave 등.
    /// 듣는 쪽 (Mac Home/Calendar VM) 은 mySharedCalendars 를 다시 로드해서
    /// 일정 생성/수정 시트의 picker 가 stale 되지 않게 한다.
    static let dozySharedCalendarsChanged = Notification.Name("dozy.sharedCalendarsChanged")
    /// NotificationRecord 가 새로 추가됨 — 파트너 공유 일정 카드 등.
    /// 듣는 쪽(Home VM) 은 알림 뱃지 즉시 갱신.
    static let dozyNotificationsChanged = Notification.Name("dozy.notificationsChanged")
}

// MARK: - UI 테스트 모드

/// XCUITest 런처가 `-uiTesting` 인자를 넘겼는지 여부.
///
/// DEBUG 빌드는 실행마다 환경 선택 다이얼로그를 띄우고 인트로 애니메이션(약 3.1초)을
/// 재생하는데, 테스트 하네스는 다이얼로그를 눌러줄 수 없어 화면 진입 자체가 막힌다.
/// 이 플래그가 켜지면 개발 환경으로 자동 진입하고 인트로를 건너뛴다.
/// Release 빌드에서는 인자와 무관하게 항상 false.
enum UITestMode {
    static let isEnabled: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uiTesting")
        #else
        return false
        #endif
    }()
}

// MARK: - App Store

enum AppStoreConfig {
    /// App Store 앱 ID (출시 후 실제 ID로 교체하세요)
    static let appID = "6762165739"
    static let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)")!
}
