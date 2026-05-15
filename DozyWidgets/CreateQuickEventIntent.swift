//
//  CreateQuickEventIntent.swift
//  DozyWidgetsExtension
//
//  위젯의 "+ 새 일정" 버튼이 실행하는 App Intent.
//  openAppWhenRun = true 라 탭 시 OS 가 메인 앱을 활성화하고,
//  perform() 은 메인 앱 프로세스에서 실행된다.
//
//  메인 앱과 widget extension 은 별도 타겟이라 NotificationCenter 이름이 직접 공유되지 않으므로
//  App Group UserDefaults 의 플래그로 통신. 메인 앱이 scenePhase active 시 플래그를 소비해
//  일정 추가 바텀시트를 띄움.
//

import AppIntents
import Foundation

struct CreateQuickEventIntent: AppIntent {

    static var title: LocalizedStringResource = "새 일정 추가"
    static var description = IntentDescription("Dozy 위젯에서 빠르게 새 일정을 추가합니다.")

    /// 탭 시 메인 앱을 활성화하고 perform 을 메인 앱 프로세스에서 실행.
    static var openAppWhenRun: Bool = true

    /// Shortcuts 앱에서 노출되어도 무방.
    static var isDiscoverable: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: CreateQuickEventIntent.appGroupID)
        defaults?.set(true, forKey: CreateQuickEventIntent.pendingFlagKey)
        return .result()
    }

    // MARK: - App Group Constants

    /// 메인 앱 / 위젯 양쪽에서 같은 값을 써야 하므로 상수로 노출.
    static let appGroupID = "group.com.dozy-ai.shared"
    static let pendingFlagKey = "pendingCreateEvent"
}
