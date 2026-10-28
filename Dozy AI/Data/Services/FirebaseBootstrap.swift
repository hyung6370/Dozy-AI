//
//  FirebaseBootstrap.swift
//  Dozy AI
//
//  [Data Layer] Firebase 초기화 · 수집 조건 공용 (#90 · #117). Analytics 와 Crashlytics 가 함께 쓴다.
//
//  - `GoogleService-Info.plist` 가 번들에 없으면 `FirebaseApp.configure()` 를 부르지 않는다
//    (공개 저장소라 plist 는 .gitignore — 새 클론 · 포크 · 테스트 호스트에서도 안전하게).
//  - DEBUG 빌드는 `-FIRAnalyticsDebugEnabled` / `-FIRDebugEnabled` 인자로 실행할 때만 수집한다.
//

import Foundation
import FirebaseCore

nonisolated enum FirebaseBootstrap {

    static var hasConfigFile: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    /// plist 가 있으면 한 번만 configure 하고 true. 없으면 false.
    @discardableResult
    static func configureIfAvailable(hasConfigFile: Bool = hasConfigFile) -> Bool {
        guard hasConfigFile else { return false }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }

    /// Release 는 항상 허용, DEBUG 는 Firebase 디버그 인자로 실행할 때만.
    static var buildAllowsCollection: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-FIRAnalyticsDebugEnabled") || args.contains("-FIRDebugEnabled")
        #else
        return true
        #endif
    }
}
