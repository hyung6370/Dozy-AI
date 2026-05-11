//
//  MainTabView.swift
//  Dozy AI
//
//  v2.0.0: 시스템 탭바를 숨기고 DozyMainTabBar 를 safeAreaInset 으로 올린다.
//  TabView 자체는 유지 → 탭별 NavigationStack/뷰 lifecycle 을 SwiftUI 가 무료로 보존.
//

import SwiftUI

struct MainTabView: View {

    private let container: DependencyContainer
    @StateObject private var calendarViewModel: CalendarViewModel
    @StateObject private var sharedCalendarViewModel: SharedCalendarViewModel
    @State private var selection: MainTab = .home
    @EnvironmentObject private var authViewModel: AuthViewModel

    init(container: DependencyContainer) {
        self.container = container
        _calendarViewModel = StateObject(wrappedValue: CalendarViewModel(container: container))
        _sharedCalendarViewModel = StateObject(wrappedValue: SharedCalendarViewModel(
            createUseCase: container.createSharedCalendarUseCase,
            joinUseCase: container.joinSharedCalendarUseCase,
            leaveUseCase: container.leaveSharedCalendarUseCase,
            regenerateUseCase: container.regenerateSharedCalendarInviteCodeUseCase,
            updateNicknameUseCase: container.updateSharedCalendarNicknameUseCase,
            service: container.sharedCalendarService
        ))
    }

    private var selectionBinding: Binding<Int> {
        Binding(
            get: { selection.rawValue },
            set: { newValue in
                if let tab = MainTab(rawValue: newValue) {
                    selection = tab
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selectionBinding) {
            HomeView(container: container, selectedTab: selectionBinding)
                .tag(MainTab.home.rawValue)
                .toolbar(.hidden, for: .tabBar)

            CalendarView(container: container, viewModel: calendarViewModel)
                .tag(MainTab.calendar.rawValue)
                .toolbar(.hidden, for: .tabBar)

            InsightDashboardView(container: container, selectedTab: selectionBinding)
                .tag(MainTab.insight.rawValue)
                .toolbar(.hidden, for: .tabBar)

            SettingsView(container: container)
                .tag(MainTab.settings.rawValue)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DozyMainTabBar(selection: $selection, onReselect: handleReselect)
        }
        .onAppear {
            calendarViewModel.loadInitialData()
        }
        .onChange(of: selection) { _, newTab in
            if newTab == .calendar { calendarViewModel.refreshData() }
        }
        .sheet(item: Binding(
            get: { authViewModel.pendingInviteCode.map { InviteCodeWrapper(code: $0) } },
            set: { if $0 == nil { authViewModel.pendingInviteCode = nil } }
        )) { wrapper in
            SharedCalendarJoinView(viewModel: sharedCalendarViewModel, initialCode: wrapper.code)
        }
    }

    private func handleReselect(_ tab: MainTab) {
        // 후속 작업: NotificationCenter.default.post(name: .dozyTabReselected, object: tab)
        // 각 화면이 ScrollViewReader 로 구독하면 더블탭 → 스크롤 투 톱 동작.
    }
}

private struct InviteCodeWrapper: Identifiable {
    let code: String
    var id: String { code }
}
