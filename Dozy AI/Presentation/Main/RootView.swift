//
//  RootView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI
import OSLog

struct RootView: View {

    let container: DependencyContainer
    @State private var showIntro = true
    @State private var showPrivacyScreen = false
    @State private var forceUpdateRequired = false

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    private let appVersionService = AppVersionService()

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

            // 강제 업데이트 화면 — 모든 UI 위에 표시하여 앱 사용 차단
            if forceUpdateRequired {
                ForceUpdateView(appStoreURL: AppStoreConfig.appStoreURL)
                    .zIndex(10)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.25), value: forceUpdateRequired)
        .task {
            await checkForceUpdate()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !showIntro else { return }

            switch newPhase {
            case .inactive, .background:
                showPrivacyScreen = true
            case .active:
                withAnimation(.easeInOut(duration: 0.4)) {
                    showPrivacyScreen = false
                }
                // 포그라운드 복귀 시에도 재체크 (사용자가 업데이트 후 돌아온 경우 해제)
                Task { await checkForceUpdate() }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Force Update

    @MainActor
    private func checkForceUpdate() async {
        guard networkMonitor.isConnected else { return }
        guard let minimumVersion = await appVersionService.fetchMinimumVersion() else { return }
        let required = appVersionService.isUpdateRequired(minimumVersion: minimumVersion)
        withAnimation {
            forceUpdateRequired = required
        }
        if required {
            Logger.network.warning("🚨 강제 업데이트 필요 — 현재: \(appVersionService.currentVersion), 최소: \(minimumVersion)")
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
