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
        view.play { finished in
            if finished { onComplete?() }
        }
        return view
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}
