//
//  LottieOverlayView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI
import Lottie

struct LottieOverlayView: View {
    let animationName: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }   // 탭해서 닫기
            
            LottieView(name: animationName, loopMode: .playOnce) {
                onDismiss()   // 애니메이션 끝나면 자동 닫기
            }
            .frame(width: 220, height: 220)
        }
    }
}
