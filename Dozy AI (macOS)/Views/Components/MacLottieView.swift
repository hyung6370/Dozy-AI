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

    /// LottieAnimationView 가 SwiftUI 의 .frame() 제안을 무시하고 자기 native viewport
    /// 크기로 렌더하는 케이스가 있어, layout() 을 오버라이드해 매 레이아웃마다 lottie 의
    /// frame 을 컨테이너 bounds 와 동기화시킨다. 이렇게 해야 .frame(width:height:) 이
    /// 시각적으로 정확히 반영됨.
    func makeNSView(context: Context) -> LottieContainerView {
        let lottie = LottieAnimationView(name: name)
        lottie.contentMode = .scaleAspectFit
        lottie.loopMode = loopMode
        lottie.animationSpeed = animationSpeed
        let container = LottieContainerView(lottie: lottie)
        lottie.play { finished in
            if finished { onComplete?() }
        }
        return container
    }

    func updateNSView(_ nsView: LottieContainerView, context: Context) {}
}

/// SwiftUI .frame 을 LottieAnimationView 가 따르도록 강제하는 컨테이너 NSView.
final class LottieContainerView: NSView {
    private let lottie: LottieAnimationView

    init(lottie: LottieAnimationView) {
        self.lottie = lottie
        super.init(frame: .zero)
        addSubview(lottie)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        lottie.frame = bounds
    }
}

#Preview {
    MacLottieView(name: "success")
        .frame(width: 200, height: 200)
}
