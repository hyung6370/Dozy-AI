//
//  FirebaseAnalyticsService.swift
//  Dozy AI
//
//  [Data Layer] Firebase Analytics 구현 (#90). iOS · macOS 앱 타깃 공통, 위젯 extension 제외.
//
//  - SPM 제품은 `FirebaseAnalyticsCore` — IDFA(IdentitySupport) · 광고 전환 SDK 를 링크하지 않아 ATT 프롬프트와
//    App Store "추적" 표기가 없다. 모듈 이름은 그대로 `FirebaseAnalytics`.
//  - `GoogleService-Info.plist` 가 번들에 없으면 Firebase 를 초기화하지 않고 아무것도 보내지 않는다
//    (설정 파일 준비 전 빌드 · 테스트 호스트 · 포크 저장소).
//  - Info.plist `FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO` 로 시작해, 사용자 토글을 읽은 뒤에만 켠다.
//  - DEBUG 빌드는 `-FIRAnalyticsDebugEnabled`(DebugView) 또는 `-FIRDebugEnabled` 인자로 실행할 때만 수집한다.
//    개발 데이터가 운영 대시보드에 섞이지 않게.
//

import Foundation
import FirebaseAnalytics
import OSLog

final class FirebaseAnalyticsService: AnalyticsServiceProtocol {

    /// Firebase 를 실제로 초기화했는지. false 면 모든 호출이 무시된다.
    private(set) var isConfigured = false
    private var isEnabled: Bool

    /// - Parameter hasConfigFile: 번들에 `GoogleService-Info.plist` 가 있는지. 테스트에서 false 를 넣어 무동작 경로를 검증한다.
    init(
        enabled: Bool = AnalyticsSettings.isEnabled(),
        hasConfigFile: Bool = FirebaseBootstrap.hasConfigFile
    ) {
        self.isEnabled = enabled
        guard FirebaseBootstrap.configureIfAvailable(hasConfigFile: hasConfigFile) else {
            Logger.analytics.info("GoogleService-Info.plist 없음 — 애널리틱스 · 크래시 리포팅 비활성")
            return
        }
        isConfigured = true
        applyCollectionState()
    }

    func track(_ event: AnalyticsEvent) {
        guard isConfigured, isEnabled, FirebaseBootstrap.buildAllowsCollection else { return }
        Analytics.logEvent(event.name, parameters: Self.firebaseParameters(event.parameters))
        Logger.analytics.debug("track \(event.name, privacy: .public)")
    }

    func setUserProperty(_ value: String?, for property: AnalyticsUserProperty) {
        guard isConfigured, isEnabled, FirebaseBootstrap.buildAllowsCollection else { return }
        Analytics.setUserProperty(value, forName: property.rawValue)
    }

    func setCollectionEnabled(_ enabled: Bool) {
        isEnabled = enabled
        applyCollectionState()
        Logger.analytics.info("사용 통계 전송 \(enabled ? "켜짐" : "꺼짐", privacy: .public)")
    }

    // MARK: - Private

    private func applyCollectionState() {
        guard isConfigured else { return }
        Analytics.setAnalyticsCollectionEnabled(isEnabled && FirebaseBootstrap.buildAllowsCollection)
    }

    static func firebaseParameters(_ parameters: [String: AnalyticsValue]) -> [String: Any]? {
        guard !parameters.isEmpty else { return nil }
        return parameters.mapValues { value -> Any in
            switch value {
            case .string(let s): return s
            case .int(let i):    return NSNumber(value: i)
            }
        }
    }
}
