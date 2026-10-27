//
//  PrivacyScreenManager.swift
//  Dozy AI
//
//  앱이 inactive / background 일 때 화면을 가리는 privacy overlay 를 별도 UIWindow
//  로 관리. SwiftUI 의 ZStack 오버레이는 window 단계 modal (키보드 / 시스템 alert /
//  sheet 등) 위에 못 올라가므로, alert level 보다 더 높은 windowLevel 의 윈도우를
//  새로 만들어 그 위에 띄운다.
//

import SwiftUI
import UIKit

@MainActor
final class PrivacyScreenManager {

    static let shared = PrivacyScreenManager()
    private var window: UIWindow?

    private init() {}

    /// privacy overlay 표시. 이미 표시 중이면 no-op.
    func show() {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .unattached })
        else { return }

        let w = UIWindow(windowScene: scene)
        // 시스템 alert / 키보드보다 위. UIWindow.Level.alert.rawValue + 1.
        w.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        let host = UIHostingController(rootView: IntroView(isPrivacy: true, onFinished: {}))
        host.view.backgroundColor = .clear
        w.rootViewController = host
        // 입력 차단 — privacy 화면이라 사용자 인터랙션 받을 필요 없음.
        w.isUserInteractionEnabled = false
        w.isHidden = false
        window = w
    }

    /// privacy overlay 숨김 + 윈도우 해제.
    func hide() {
        window?.isHidden = true
        window = nil
    }
}
