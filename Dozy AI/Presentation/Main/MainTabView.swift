//
//  MainTabView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI

struct MainTabView: View {

    private let container: DependencyContainer
    @StateObject private var calendarViewModel: CalendarViewModel
    @StateObject private var sharedCalendarViewModel: SharedCalendarViewModel
    @State private var selectedTab = 0
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authViewModel: AuthViewModel

    private var homeIconName: String {
        let isSelected = selectedTab == 0
        return colorScheme == .dark
            ? (isSelected ? "Dark-House-selected" : "Dark-House")
            : (isSelected ? "Light-House-selected" : "Light-House")
    }

    private var settingIconName: String {
        let isSelected = selectedTab == 3
        return colorScheme == .dark
            ? (isSelected ? "Dark-Setting-selected" : "Dark-Setting")
            : (isSelected ? "Light-Setting-selected" : "Light-Setting")
    }

    private var insightIconName: String {
        let isSelected = selectedTab == 2
        return colorScheme == .dark
            ? (isSelected ? "Dark-Insight-selectd" : "Dark-Insight")
            : (isSelected ? "Light-Insight-selected" : "Light-Insight")
    }

    private var calendarIconName: String {
        let isSelected = selectedTab == 1
        return colorScheme == .dark
            ? (isSelected ? "Dark-Calendar-selected" : "Dark-Calendar")
            : (isSelected ? "Light-Calendar-selected" : "Light-Calendar")
    }

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

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(container: container, selectedTab: $selectedTab)
                .tabItem { Label("홈", image: homeIconName) }
                .tag(0)

            CalendarView(container: container, viewModel: calendarViewModel)
                .tabItem { Label("캘린더", image: calendarIconName) }
                .tag(1)

            InsightDashboardView(container: container, selectedTab: $selectedTab)
                .tabItem { Label("인사이트", image: insightIconName) }
                .tag(2)

            SettingsView(container: container)
                .tabItem { Label("설정", image: settingIconName) }
                .tag(3)
        }
        .onAppear {
            calendarViewModel.loadInitialData()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 { calendarViewModel.refreshData() }
        }
        .sheet(item: Binding(
            get: { authViewModel.pendingInviteCode.map { InviteCodeWrapper(code: $0) } },
            set: { if $0 == nil { authViewModel.pendingInviteCode = nil } }
        )) { wrapper in
            SharedCalendarJoinView(viewModel: sharedCalendarViewModel, initialCode: wrapper.code)
        }
    }
}

private struct InviteCodeWrapper: Identifiable {
    let code: String
    var id: String { code }
}
