//
//  Dozy_AIApp.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import SwiftUI
import SwiftData

@main
struct Dozy_AIApp: App {
    
    // SwiftData에 등록할 모델 목록
    private let modelContainer: ModelContainer
    
    // DI Container - 앱 전체 서비스 관리
    @StateObject private var container = DependencyContainer()
    
    init() {
        do {
            let schema = Schema([
                WorkLog.self,
                UserPattern.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer 초기화 실패: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(container)
        }
        .modelContainer(modelContainer)
    }
}
