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
    @Environment(\.scenePhase) private var scenePhase

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
                handleWidgetDeepLink(url)
            }
            .onAppear {
                Task {
                    await authViewModel.clearSessionIfReinstalled()
                    authViewModel.startAuthListener()
                }
                // 콜드 스타트 시점에 이미 플래그가 set 되어 있을 수 있음 (CreateQuickEventIntent
                // 가 launch 를 트리거한 경우). scenePhase 콜백이 항상 active 로 떨어진다는
                // 보장이 없어 onAppear 에서도 한 번 소비.
                consumePendingCreateEventFlag()
            }
            .onChange(of: scenePhase) { _, phase in
                // 위젯의 CreateQuickEventIntent 가 perform 에서 App Group 플래그를 set 함.
                // 메인 앱이 foreground 로 돌아온 시점에 플래그를 소비해 일정 생성 시트를 띄움.
                if phase == .active { consumePendingCreateEventFlag() }
            }
            .environmentObject(authViewModel)
    }

    /// App Group UserDefaults 의 `pendingCreateEvent` 플래그를 읽고, 켜져 있으면
    /// 끄고 `dozyWidgetOpenAddEvent` 알림을 게시 → `MainTabView` 가 홈 탭 + 생성 시트 오픈.
    private func consumePendingCreateEventFlag() {
        let defaults = UserDefaults(suiteName: CreateQuickEventIntent.appGroupID)
        guard defaults?.bool(forKey: CreateQuickEventIntent.pendingFlagKey) == true else { return }
        defaults?.set(false, forKey: CreateQuickEventIntent.pendingFlagKey)
        NotificationCenter.default.post(name: .dozyWidgetOpenAddEvent, object: nil)
    }

    /// 위젯의 widgetURL/Link 탭으로 들어온 deep link 처리.
    /// 지원 URL:
    /// - `dozy-ai://add-event` → 일정 추가 시트
    /// - `dozy-ai://calendar` → 캘린더 탭
    /// - `dozy-ai://event-detail?id=<id>` → 해당 일정 상세 시트
    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == "dozy-ai" else { return }
        let host = url.host?.lowercased() ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        switch host {
        case "add-event":
            NotificationCenter.default.post(name: .dozyWidgetOpenAddEvent, object: nil)
        case "calendar":
            NotificationCenter.default.post(name: .dozyWidgetOpenCalendar, object: nil)
        case "event-detail":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let id = components?.queryItems?.first(where: { $0.name == "id" })?.value, !id.isEmpty {
                NotificationCenter.default.post(name: .dozyWidgetOpenEventDetail, object: id)
            }
        default:
            break
        }
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

// MARK: - Widget Deep Link Notifications

extension Notification.Name {
    /// 위젯 (accessoryCircular) 에서 일정 추가 시트 오픈 요청.
    /// `Dozy_AIApp.handleWidgetDeepLink` 가 `dozy-ai://add-event` 수신 시 post.
    /// `MainTabView` 가 observe 해서 홈 탭으로 이동 + `showCreateEvent = true`.
    static let dozyWidgetOpenAddEvent = Notification.Name("dozyWidgetOpenAddEvent")

    /// 위젯 (systemLarge 의 미니 캘린더, 하단 일정 리스트) 탭으로 들어옴 → 캘린더 탭으로 이동.
    /// `dozy-ai://calendar` 수신 시 post.
    static let dozyWidgetOpenCalendar = Notification.Name("dozyWidgetOpenCalendar")

    /// 위젯 (accessoryRectangular 잠금화면) 탭으로 들어옴 → 해당 일정 상세 시트 오픈.
    /// `dozy-ai://event-detail?id=<id>` 수신 시 eventID 를 `object` 로 post.
    /// `MainTabView` 가 홈 탭으로 이동시키고, `HomeView` 가 events 목록에서 찾아 selectedEvent 설정.
    static let dozyWidgetOpenEventDetail = Notification.Name("dozyWidgetOpenEventDetail")
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
        // 위젯과 공유할 App Group UserDefaults 로 테마 storage 일회성 이전.
        // 기존 사용자의 UserDefaults.standard 값이 App Group 쪽에 복사됨.
        DozyBackgroundTheme.migrateThemeStorageIfNeeded()

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
