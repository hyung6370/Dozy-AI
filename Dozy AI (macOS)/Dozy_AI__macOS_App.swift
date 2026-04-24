//
//  Dozy_AI__macOS_App.swift
//  Dozy AI (macOS)
//

import SwiftUI
import SwiftData
import Combine
import GoogleSignIn
import OSLog

@main
struct Dozy_AI__macOS_App: App {
    @StateObject private var coordinator = MacAppCoordinator()

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                #if DEBUG
                if coordinator.isReady,
                   let container = coordinator.container,
                   let authViewModel = coordinator.authViewModel {
                    mainView(container: container, authViewModel: authViewModel)
                } else {
                    MacEnvironmentPickerView { env in
                        AppEnvironment.current = env
                        Logger.app.info("환경 선택: \(env.displayName)")
                        coordinator.setup()
                    }
                }
                #else
                if let container = coordinator.container,
                   let authViewModel = coordinator.authViewModel {
                    mainView(container: container, authViewModel: authViewModel)
                } else {
                    Color.clear
                }
                #endif
            }
            .frame(minWidth: 900, minHeight: 600)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            if let container = coordinator.container,
               let menuBarViewModel = coordinator.menuBarViewModel {
                MacMenuBarView(container: container, viewModel: menuBarViewModel)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Dozy 준비 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 200, height: 80)
            }
        } label: {
            if let vm = coordinator.menuBarViewModel {
                MacMenuBarIcon(viewModel: vm)
            } else {
                Image(systemName: "calendar")
            }
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private func mainView(container: DependencyContainer, authViewModel: MacAuthViewModel) -> some View {
        MacAppRootView()
            .environmentObject(container)
            .environmentObject(authViewModel)
            .modelContainer(container.modelContainer)
    }
}

// MARK: - MacAppCoordinator

/// DependencyContainer(supabase 포함)를 환경 선택 이후에 초기화하기 위한 조율 객체.
/// DEBUG: MacEnvironmentPickerView 에서 환경 선택 후 setup() 호출
/// Release: init() 에서 즉시 setup() 호출
final class MacAppCoordinator: ObservableObject {
    @Published private(set) var isReady = false
    private(set) var container: DependencyContainer?
    private(set) var authViewModel: MacAuthViewModel?
    private(set) var menuBarViewModel: MacMenuBarViewModel?

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
        authViewModel = MacAuthViewModel(
            authService: c.authService,
            modelContainer: c.modelContainer
        )
        let mb = MacMenuBarViewModel(container: c)
        mb.loadTodayData()
        menuBarViewModel = mb
        container = c
        isReady = true
    }
}

// MARK: - MacEnvironmentPickerView

#if DEBUG
struct MacEnvironmentPickerView: View {
    let onSelect: (AppEnvironment) -> Void
    @State private var showAlert = true

    var body: some View {
        Color(NSColor.windowBackgroundColor)
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
