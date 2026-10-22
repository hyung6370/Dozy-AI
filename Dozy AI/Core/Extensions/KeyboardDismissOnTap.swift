//
//  KeyboardDismissOnTap.swift
//  Dozy AI
//
//  키보드가 올라와 있을 때 빈 곳(여백)을 탭하면 키보드를 내린다.
//
//  SwiftUI `onTapGesture` 를 루트에 거는 방식은 자식 버튼·스크롤과 제스처가 겹쳐 꼬이기 쉬워,
//  윈도우에 UITapGestureRecognizer 를 하나 달아 두는 UIKit 방식을 쓴다.
//  - cancelsTouchesInView = false → 원래 탭(버튼 등)은 그대로 전달된다.
//  - 다른 제스처와 동시 인식 → 스크롤·드래그를 막지 않는다.
//  - 텍스트 입력 뷰(UITextField/UITextView) 위의 탭은 무시 → 다른 입력란으로 옮겨 갈 때 깜빡이지 않는다.
//  - 윈도우 단위라 같은 윈도우에 뜨는 시트 안에서도 동작한다.
//

import SwiftUI
import UIKit

extension View {
    /// 앱 루트에 한 번만 건다. 뷰가 윈도우에 붙는 시점에 그 윈도우에 탭 인식기를 설치한다(중복 설치 방지).
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissOnTapInstaller().frame(width: 0, height: 0))
    }
}

private struct KeyboardDismissOnTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        private static var installedWindows = NSHashTable<UIWindow>.weakObjects()
        private let delegate = TapDelegate()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !Self.installedWindows.contains(window) else { return }
            Self.installedWindows.add(window)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = delegate
            window.addGestureRecognizer(tap)
        }

        @objc private func handleTap() {
            window?.endEditing(true)
        }
    }

    final class TapDelegate: NSObject, UIGestureRecognizerDelegate {
        /// 입력란 자체를 누른 탭은 받지 않는다 — 포커스 이동이 키보드 내림으로 끊기지 않게.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let v = view {
                if v is UITextInput { return false }
                view = v.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
