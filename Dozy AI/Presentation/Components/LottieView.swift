//
//  LottieView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .playOnce
    var animationSpeed: CGFloat = 1.0
    var onComplete: (() -> Void)? = nil

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = loopMode
        view.animationSpeed = animationSpeed
        // 기본값(.pause)으로는 백그라운드 진입 시 멈춘 채 복귀 후에도 재생이 재개되지 않아
        // 완료 콜백이 영영 호출되지 않음 → 오버레이가 화면에 박제됨.
        view.backgroundBehavior = .pauseAndRestore
        view.play { finished in
            if finished { onComplete?() }
        }
        return view
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}
