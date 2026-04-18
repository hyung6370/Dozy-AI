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

    @StateObject private var container: DependencyContainer
    @StateObject private var authViewModel: AuthViewModel
    private var cancellables = Set<AnyCancellable>()

    #if DEBUG
    @State private var environmentSelected = false
    #endif

    init() {
        let container = DependencyContainer()
        _container = StateObject(wrappedValue: container)
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            modelContext: container.modelContainer.mainContext,
            realtimeService: container.sharedCalendarRealtimeService
        ))
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if environmentSelected {
                mainView
            } else {
                EnvironmentPickerView(isSelected: $environmentSelected)
            }
            #else
            mainView
            #endif
        }
        // DependencyContainer가 소유한 ModelContainer를 환경에 등록합니다.
        // @Query 등 SwiftUI 내장 SwiftData 기능을 위해 필요합니다.
        .modelContainer(container.modelContainer)
    }

    @ViewBuilder
    private var mainView: some View {
        RootView(container: container)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
                _ = container.naverSignInService.handle(url: url)
                handleUniversalLink(url)
            }
            .onAppear {
                Task {
                    await authViewModel.clearSessionIfReinstalled()
                    authViewModel.startAuthListener()
                }
            }
            .environmentObject(authViewModel)
    }

    private func handleUniversalLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              ["dozyapp.kr", "www.dozyapp.kr"].contains(components.host),
              components.path == "/shared-calendar/join",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return }
        authViewModel.pendingInviteCode = code
    }
}

#if DEBUG
struct EnvironmentPickerView: View {
    @Binding var isSelected: Bool
    @State private var showAlert = true

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .alert("환경 선택", isPresented: $showAlert) {
                Button("🛠 개발 (Dev)") {
                    AppEnvironment.current = .development
                    Logger.app.info("🛠 환경 선택: 개발 (Dev)")
                    isSelected = true
                }
                Button("🚀 운영 (Prod)", role: .destructive) {
                    AppEnvironment.current = .production
                    Logger.app.info("🚀 환경 선택: 운영 (Prod)")
                    isSelected = true
                }
            } message: {
                Text("연결할 Supabase 환경을 선택하세요.\n앱을 재설치하면 다시 선택할 수 있습니다.")
            }
    }
}
#endif
