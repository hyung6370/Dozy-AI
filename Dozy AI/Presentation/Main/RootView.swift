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

    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        ZStack {
            MainTabView(container: container)

            // 오프라인 배너 — 네트워크 끊김 시 상단에 표시
            if !networkMonitor.isConnected {
                VStack {
                    offlineBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .zIndex(1)
                .ignoresSafeArea(edges: .top)
            }

            if showIntro {
                IntroView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showIntro = false
                    }
                }
                .zIndex(2)
            }

            if showPrivacyScreen {
                IntroView(isPrivacy: true, onFinished: {})
                    .zIndex(3)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: networkMonitor.isConnected)
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

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.footnote)
                .fontWeight(.semibold)
            Text("네트워크 연결 없음 — 오프라인 모드로 동작 중입니다")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .padding(.top, 50) // safe area top 여백
    }
}
