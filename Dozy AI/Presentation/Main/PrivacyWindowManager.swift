//
//  PrivacyWindowManager.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/13/26.
//
//  Sheet나 모달보다 높은 UIWindow level에서 프라이버시 화면을 표시합니다.
//  ZStack zIndex 방식은 sheet 위로 올라오지 못하는 문제가 있어 UIWindow로 교체합니다.

import UIKit
import SwiftUI

@MainActor
final class PrivacyWindowManager {

    static let shared = PrivacyWindowManager()
    private var privacyWindow: UIWindow?

    // MARK: - Show

    func show() {
        guard privacyWindow == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0 is UIWindowScene }) as? UIWindowScene
        else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1   // 모든 시트·알림보다 위
        window.backgroundColor = .clear

        let hostingVC = UIHostingController(
            rootView: IntroView(isPrivacy: true, onFinished: {})
        )
        hostingVC.view.backgroundColor = .clear
        window.rootViewController = hostingVC
        window.isHidden = false
        privacyWindow = window
    }

    // MARK: - Hide

    func hide(animated: Bool = true) {
        guard let window = privacyWindow else { return }

        if animated {
            UIView.animate(withDuration: 0.4) {
                window.alpha = 0
            } completion: { _ in
                window.isHidden = true
                self.privacyWindow = nil
            }
        } else {
            window.isHidden = true
            privacyWindow = nil
        }
    }
}
