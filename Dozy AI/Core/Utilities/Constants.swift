//
//  Constants.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation

extension Notification.Name {
    static let dozyDataSyncCompleted = Notification.Name("dozy.dataSyncCompleted")
    static let googleSignInRestored = Notification.Name("dozy.googleSignInRestored")
}

// MARK: - App Store

enum AppStoreConfig {
    /// App Store 앱 ID (출시 후 실제 ID로 교체하세요)
    static let appID = "6762165739"
    static let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)")!
}
