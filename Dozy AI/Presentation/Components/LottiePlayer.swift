//
//  LottiePlayer.swift
//  Dozy AI
//
//  trigger 값이 바뀔 때마다 처음부터 1회 재생하는 Lottie 래퍼.
//  - 기존 LottieView 는 makeUIView 시점에만 재생되므로 "탭 시 재생" 같은 동작이 어렵다.
//  - 이 컴포넌트는 부모가 trigger(예: Int 카운터)를 증가시키면 stop() 후 play() 한다.
//

import SwiftUI
import Lottie

struct LottiePlayer: UIViewRepresentable {
    let name: String
    /// 값이 바뀔 때마다 재생을 다시 시작.
    var trigger: Int
    /// true 면 처음에 첫 프레임만 표시하고 멈춤. false 면 makeUIView 시점에 1회 재생.
    var startsPaused: Bool = true
    var animationSpeed: CGFloat = 1.0

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = .playOnce
        view.animationSpeed = animationSpeed
        // 기본값(.pause)으로는 백그라운드 진입 시 멈춘 채 복귀 후에도 재생이 재개되지 않아
        // 마지막 프레임에서 박제되는 현상이 발생함.
        view.backgroundBehavior = .pauseAndRestore
        // intrinsic content size 가 SwiftUI .frame 을 무시하지 않도록 우선순위를 낮춤.
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        if startsPaused {
            view.currentProgress = 0
            view.pause()
        } else {
            view.play()
        }
        context.coordinator.lastTrigger = trigger
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if context.coordinator.lastTrigger != trigger {
            context.coordinator.lastTrigger = trigger
            uiView.stop()
            uiView.play()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastTrigger: Int = .min
    }
}
