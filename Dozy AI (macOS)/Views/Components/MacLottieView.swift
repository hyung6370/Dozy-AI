//
//  MacLottieView.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 5/4/26.
//

import SwiftUI
import Lottie

struct MacLottieView: NSViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .playOnce
    var animationSpeed: CGFloat = 1.0
    var onComplete: (() -> Void)? = nil
    
    func makeNSView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = loopMode
        view.animationSpeed = animationSpeed
        view.play { finished in
            if finished { onComplete?() }
        }
        return view
    }
    
    func updateNSView(_ nsView: LottieAnimationView, context: Context) {}
}

#Preview {
    MacLottieView(name: "success")
        .frame(width: 200, height: 200)
}
