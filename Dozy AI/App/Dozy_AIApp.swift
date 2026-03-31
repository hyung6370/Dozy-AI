//
//  Dozy_AIApp.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct Dozy_AIApp: App {

    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            MainTabView(container: container)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    _ = container.naverSignInService.handle(url: url)
                }
        }
        // DependencyContainer가 소유한 ModelContainer를 환경에 등록합니다.
        // @Query 등 SwiftUI 내장 SwiftData 기능을 위해 필요합니다.
        .modelContainer(container.modelContainer)
    }
}
