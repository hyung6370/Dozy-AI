//
//  MainTabView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI

struct MainTabView: View {
    
    private let container: DependencyContainer
    
    init(container: DependencyContainer) {
        self.container = container
    }
    
    var body: some View {
        TabView {
            HomeView(container: container)
                .tabItem { Label("홈", systemImage: "house.fill") }
            
            CalendarView(container: container)
                .tabItem { Label("캘린더", systemImage: "calendar") }
            
            InsightDashboardView(container: container)
                .tabItem { Label("인사이트", systemImage: "chart.bar.fill") }
            
            CalendarSettingsView(
                sourceManager: container.calendarSourceManager,
                googleSignInService: container.googleSignInService,
                naverSignInService: container.naverSignInService
            )
            .tabItem { Label("설정", systemImage: "gear") }
        }
    }
}
