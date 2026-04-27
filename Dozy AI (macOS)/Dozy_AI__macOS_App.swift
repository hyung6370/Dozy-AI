//
//  Dozy_AI__macOS_App.swift
//  Dozy AI (macOS)
//

import SwiftUI
import SwiftData
import Combine
import GoogleSignIn
import OSLog

// MARK: - Locale (DatePicker 용 24시간 강제)

extension Locale {
    /// 한국어 + 24시간 hourCycle 강제. DatePicker 가 시스템 12/24h 설정과 무관하게
    /// 24시간으로 동작 — 시작/종료 시각에 18 입력 시 자동 18:00 으로 인식됨.
    static let koreanForce24h: Locale = {
        var components = Locale.Components(locale: Locale(identifier: "ko_KR"))
        components.hourCycle = .zeroToTwentyThree
        return Locale(components: components)
    }()
}

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
        .commands {
            // File 메뉴의 "New..." 를 "새 일정" 으로 대체
            CommandGroup(replacing: .newItem) {
                Button("새 일정") {
                    NotificationCenter.default.post(name: .dozyRequestNewEvent, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            
            // File 메뉴 "새 일정" 아래에 추가 항목
            CommandGroup(after: .newItem) {
                Divider()
                Button("새로고침") {
                    NotificationCenter.default.post(name: .dozyRequestRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                if coordinator.authViewModel != nil {
                    Divider()
                    Button("로그아웃") {
                        coordinator.authViewModel?.signOut()
                    }
                }
            }
            
            // View 메뉴의 Sidebar 아래에 섹션 전환 단축키
            CommandGroup(after: .sidebar) {
                Button("오늘") { coordinator.selectedSection = .today }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("캘린더") { coordinator.selectedSection = .calendar }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("인사이트") { coordinator.selectedSection = .insights }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("설정") { coordinator.selectedSection = .settings }
                    .keyboardShortcut("4", modifiers: [.command])
            }
        }

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
            .environmentObject(coordinator)
            .modelContainer(container.modelContainer)
    }
}

// MARK: - MacAppCoordinator

/// DependencyContainer(supabase 포함)를 환경 선택 이후에 초기화하기 위한 조율 객체.
/// DEBUG: MacEnvironmentPickerView 에서 환경 선택 후 setup() 호출
/// Release: init() 에서 즉시 setup() 호출
final class MacAppCoordinator: ObservableObject {
    @Published private(set) var isReady = false
    @Published var selectedSection: MacSection? = .today
    private(set) var container: DependencyContainer?
    private(set) var authViewModel: MacAuthViewModel?
    private(set) var menuBarViewModel: MacMenuBarViewModel?
    private(set) var homeViewModel: MacHomeViewModel?
    private(set) var calendarViewModel: MacCalendarViewModel?

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

        // Home / Calendar VM 을 앱 런치 시점에 미리 만들고 데이터 프리-로드.
        // 사용자가 탭 누를 때엔 이미 @Published 에 데이터가 차있어서 즉시 표시됨.
        let home = MacHomeViewModel(container: c)
        home.loadTodayData()
        homeViewModel = home

        let cal = MacCalendarViewModel(container: c)
        cal.loadEventsForCurrentMonth()   // 현재 월 + prefetchAdjacent(±2) 발동
        cal.prewarmWideWindow()            // ±3 까지 추가 pre-warm
        calendarViewModel = cal

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
