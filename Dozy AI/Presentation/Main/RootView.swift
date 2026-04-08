//
//  RootView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

struct RootView: View {

    let container: DependencyContainer
    @State private var showIntro = true
    @State private var showPrivacyScreen = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MainTabView(container: container)

            if showIntro {
                IntroView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showIntro = false
                    }
                }
                .zIndex(1)
            }
            
            if showPrivacyScreen {
                IntroView(isPrivacy: true, onFinished: {})
                    .zIndex(2)
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 인트로 중에는 privacy screen 무시
            guard !showIntro else { return }
            
            switch newPhase {
            case .inactive, .background:
                showPrivacyScreen = true
            case .active:
                withAnimation(.easeInOut(duration: 0.4)) {
                    showPrivacyScreen = false
                }
            @unknown default:
                break
            }
        }
    }
}
