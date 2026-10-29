//
//  FirebaseCrashReportingService.swift
//  Dozy AI
//
//  [Data Layer] Firebase Crashlytics 구현 (#117). iOS · macOS 앱 타깃 공통, 위젯 extension 제외.
//
//  - Info.plist `FirebaseCrashlyticsCollectionEnabled = NO` 로 시작해, 설정 "사용 통계 전송" 토글을 읽은 뒤에만 켠다.
//    토글은 Analytics 와 같은 값 하나(AnalyticsSettings)를 쓴다 — 사용자가 "앱이 보내는 것"을 한 번에 끈다.
//  - 사용자 식별자(setUserID)는 설정하지 않는다. 비치명 오류는 CrashReporting.sanitized 로 메시지를 버린다.
//  - plist 가 없으면 아무것도 하지 않는다 (FirebaseBootstrap).
//

import Foundation
import FirebaseCrashlytics
import OSLog

nonisolated final class FirebaseCrashReportingService: CrashReportingServiceProtocol {

    private(set) var isConfigured = false
    private var isEnabled: Bool

    init(enabled: Bool = AnalyticsSettings.isEnabled(), hasConfigFile: Bool = FirebaseBootstrap.hasConfigFile) {
        self.isEnabled = enabled
        guard FirebaseBootstrap.configureIfAvailable(hasConfigFile: hasConfigFile) else { return }
        isConfigured = true
        applyCollectionState()
    }

    func record(_ error: Error, context: String) {
        guard isActive else { return }
        Crashlytics.crashlytics().record(error: CrashReporting.sanitized(error, context: context))
        Logger.analytics.debug("non-fatal \(context, privacy: .public)")
    }

    func log(_ message: String) {
        guard isActive else { return }
        Crashlytics.crashlytics().log(message)
    }

    func setCollectionEnabled(_ enabled: Bool) {
        isEnabled = enabled
        applyCollectionState()
    }

    // MARK: - Private

    private var isActive: Bool { isConfigured && isEnabled && FirebaseBootstrap.buildAllowsCollection }

    private func applyCollectionState() {
        guard isConfigured else { return }
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(isEnabled && FirebaseBootstrap.buildAllowsCollection)
    }
}

// MARK: - 수신 확인용 테스트 크래시

/// Xcode 스킴 인자 `-DozyCrashlyticsTestCrash` 로 실행하면 3초 뒤 일부러 크래시한다 (#117).
/// 크래시 보고는 **다음 실행 때** 전송되므로, 크래시 후 인자를 빼고 앱을 다시 열어야 콘솔에 보인다.
/// DEBUG 빌드에서는 수집 조건(`-FIRDebugEnabled` 등)도 함께 넣어야 전송된다. 사용자가 이 인자로 앱을 띄울 방법은 없다.
enum CrashReportingTestHook {
    static let argument = "-DozyCrashlyticsTestCrash"

    static func scheduleTestCrashIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(argument) else { return }
        Logger.analytics.warning("Crashlytics 테스트 크래시 3초 후 발생")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            fatalError("Crashlytics 테스트 크래시 (#117)")
        }
    }
}
