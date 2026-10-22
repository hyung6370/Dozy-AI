//
//  View+DozyBackButton.swift
//  Dozy AI
//
//  NavigationStack 으로 push 된 화면의 시스템 뒤로가기를 `btn_navi_back` 에셋 버튼으로 바꾼다.
//  - 에셋은 라이트(짙은 회색)/다크(흰색) 변형을 갖고 있어 SwiftUI Image 가 모드에 맞춰 자동 선택한다.
//    (UINavigationBarAppearance 의 backIndicatorImage 는 다크 변형을 해석하지 못해 이 방식을 쓴다.)
//  - 시스템 back 을 숨기면 SwiftUI 가 스와이프 백 제스처를 꺼 버리므로, 네비게이션 컨트롤러의
//    interactivePopGestureRecognizer 를 다시 켜고 "루트가 아닐 때만" 시작하도록 delegate 를 건다.
//  push 되는 화면의 `.navigationBarTitleDisplayMode` 옆에 `.dozyBackButton()` 한 줄을 붙인다.
//  ⚠️ 화면이 자체 `.toolbar { ToolbarItem(.topBarLeading) }` 를 가지면(편집 버튼 등) 그 `.toolbar` 보다
//     **뒤(바깥)** 에 붙여야 뒤로가기가 가장 왼쪽에 온다 — 바깥 modifier 의 leading 아이템이 먼저 놓인다.
//

import SwiftUI
import UIKit
import ObjectiveC

extension View {
    func dozyBackButton() -> some View {
        modifier(DozyBackButtonModifier())
    }
}

private struct DozyBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image("btn_navi_back")
                            .renderingMode(.original)   // 에셋 색 그대로 (다크 변형은 에셋 카탈로그가 고른다)
                    }
                    .accessibilityLabel("뒤로")
                    .accessibilityIdentifier("btn_navi_back")
                }
            }
            .background(InteractivePopEnabler().frame(width: 0, height: 0))
    }
}

// MARK: - 스와이프 백 복구

private struct InteractivePopEnabler: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ uiView: ProbeView, context: Context) { uiView.enable() }

    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            enable()
        }

        func enable() {
            guard window != nil, let nav = navigationController() else { return }
            PopDelegate.install(on: nav)
        }

        /// 리스폰더 체인을 따라 올라가 이 뷰를 담고 있는 UINavigationController 를 찾는다.
        private func navigationController() -> UINavigationController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let vc = current as? UIViewController {
                    if let nav = vc as? UINavigationController { return nav }
                    if let nav = vc.navigationController { return nav }
                }
                responder = current.next
            }
            return nil
        }
    }

    /// 루트가 아닐 때만 pop 제스처를 시작시킨다 — 루트에서 제스처가 시작되면 네비게이션이 멈추는 UIKit 고질병 방지.
    final class PopDelegate: NSObject, UIGestureRecognizerDelegate {
        private static var key: UInt8 = 0
        private weak var nav: UINavigationController?

        static func install(on nav: UINavigationController) {
            guard let gesture = nav.interactivePopGestureRecognizer else { return }
            let delegate: PopDelegate
            if let existing = objc_getAssociatedObject(nav, &key) as? PopDelegate {
                delegate = existing
            } else {
                delegate = PopDelegate()
                delegate.nav = nav
                objc_setAssociatedObject(nav, &key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            gesture.delegate = delegate
            gesture.isEnabled = true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (nav?.viewControllers.count ?? 0) > 1
        }
    }
}
