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
}

// MARK: - App Store

enum AppStoreConfig {
    /// App Store 앱 ID (출시 후 실제 ID로 교체하세요)
    static let appID = "6762165739"
    static let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)")!
}
