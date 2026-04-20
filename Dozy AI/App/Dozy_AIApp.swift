//
//  Dozy_AIApp.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import SwiftUI
import SwiftData
import GoogleSignIn
import Combine
import OSLog

@main
struct Dozy_AIApp: App {

    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if coordinator.isReady,
               let container = coordinator.container,
               let authViewModel = coordinator.authViewModel {
                mainView(container: container, authViewModel: authViewModel)
                    .modelContainer(container.modelContainer)
            } else {
                EnvironmentPickerView { env in
                    AppEnvironment.current = env
                    Logger.app.info("환경 선택: \(env.displayName)")
                    coordinator.setup()
                }
            }
            #else
            if let container = coordinator.container,
               let authViewModel = coordinator.authViewModel {
                mainView(container: container, authViewModel: authViewModel)
                    .modelContainer(container.modelContainer)
            } else {
                Color.clear
            }
            #endif
        }
    }

    @ViewBuilder
    private func mainView(container: DependencyContainer, authViewModel: AuthViewModel) -> some View {
        RootView(container: container)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
                _ = container.naverSignInService.handle(url: url)
                handleUniversalLink(url, authViewModel: authViewModel)
            }
            .onAppear {
                Task {
                    await authViewModel.clearSessionIfReinstalled()
                    authViewModel.startAuthListener()
                }
            }
            .environmentObject(authViewModel)
    }

    private func handleUniversalLink(_ url: URL, authViewModel: AuthViewModel) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              ["dozyapp.kr", "www.dozyapp.kr"].contains(components.host),
              components.path == "/shared-calendar/join",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return }
        authViewModel.pendingInviteCode = code
    }
}

// MARK: - AppCoordinator

/// DependencyContainer(supabase 포함)를 환경 선택 이후에 초기화하기 위한 조율 객체.
/// DEBUG: EnvironmentPickerView에서 환경 선택 후 setup() 호출
/// Release: init()에서 즉시 setup() 호출
final class AppCoordinator: ObservableObject {
    @Published private(set) var isReady = false
    private(set) var container: DependencyContainer?
    private(set) var authViewModel: AuthViewModel?

    init() {
        #if !DEBUG
        setup()
        #endif
    }

    func setup() {
        #if DEBUG
        rebuildSupabaseClient()
        #endif
        let c = DependencyContainer()
        authViewModel = AuthViewModel(
            modelContext: c.modelContainer.mainContext,
            authService: c.authService,
            sharedCalendarService: c.sharedCalendarService,
            realtimeService: c.sharedCalendarRealtimeService
        )
        container = c
        isReady = true
    }
}

// MARK: - EnvironmentPickerView

#if DEBUG
struct EnvironmentPickerView: View {
    let onSelect: (AppEnvironment) -> Void
    @State private var showAlert = true

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .alert("환경 선택", isPresented: $showAlert) {
                Button("🛠 개발 (Dev)") {
                    Logger.app.info("🛠 환경 선택: 개발 (Dev)")
                    onSelect(.development)
                }
                Button("🚀 운영 (Prod)", role: .destructive) {
                    Logger.app.info("🚀 환경 선택: 운영 (Prod)")
                    onSelect(.production)
                }
            } message: {
                Text("연결할 Supabase 환경을 선택하세요.\n앱을 재설치하면 다시 선택할 수 있습니다.")
            }
    }
}
#endif
