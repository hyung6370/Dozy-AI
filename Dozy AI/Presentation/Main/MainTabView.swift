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
    @State private var selectedTab = 0

    init(container: DependencyContainer) {
        self.container = container
        _calendarViewModel = StateObject(wrappedValue: CalendarViewModel(container: container))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(container: container, selectedTab: $selectedTab)
                .tabItem { Label("홈", image: "house") }
                .tag(0)

            CalendarView(viewModel: calendarViewModel)
                .tabItem { Label("캘린더", image: "event") }
                .tag(1)

            InsightDashboardView(container: container)
                .tabItem { Label("인사이트", image: "poll") }
                .tag(2)

            SettingsView(container: container)
                .tabItem { Label("설정", image: "settings") }
                .tag(3)
        }
        .onAppear {
            calendarViewModel.loadInitialData()
        }
    }
}
