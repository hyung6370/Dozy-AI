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

@main
struct Dozy_AIApp: App {

    @StateObject private var container: DependencyContainer
    @StateObject private var authViewModel: AuthViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let container = DependencyContainer()
        _container = StateObject(wrappedValue: container)
        _authViewModel = StateObject(wrappedValue: AuthViewModel(modelContext: container.modelContainer.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    _ = container.naverSignInService.handle(url: url)
                }
                .onAppear {
                    container.notificationService.requestAuthorization()
                        .sink { _ in }
                        .store(in: &container.notificationCancellables)
                }
                .environmentObject(authViewModel)
        }
        // DependencyContainer가 소유한 ModelContainer를 환경에 등록합니다.
        // @Query 등 SwiftUI 내장 SwiftData 기능을 위해 필요합니다.
        .modelContainer(container.modelContainer)
    }
}
