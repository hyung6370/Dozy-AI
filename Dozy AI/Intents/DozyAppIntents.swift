//
//  DozyAppIntents.swift
//  Dozy AI
//
//  [Phase 4 - Siri / Shortcuts]
//  App Shortcuts 등록 + 인텐트들이 공유하는 저장소 접근 헬퍼 + "음성 메모" 인텐트.
//
//  인텐트는 메인 앱 프로세스 안에서 실행된다 (extension 아님). 그러나 앱이 떠 있지 않을 때
//  Siri 가 호출하면 iOS 가 앱을 백그라운드로 띄워 perform() 만 돌리므로 DependencyContainer 가
//  준비돼 있다는 보장이 없다 (DEBUG 는 환경 선택 전까지 nil).
//  → AppCoordinator.setup() 이 register 해 둔 컨테이너가 있으면 그걸 쓰고,
//    없으면 위젯(ToggleEventCompletionIntent)과 같은 방식으로 App Group store 를 직접 연다.
//

import AppIntents
import Foundation
import SwiftData

// MARK: - App Shortcuts

struct DozyShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWorkMemoIntent(),
            phrases: [
                "\(.applicationName)에 메모 남겨줘",
                "\(.applicationName)에 기록해줘",
                "Log a memo in \(.applicationName)"
            ],
            shortTitle: "메모 기록",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: SummarizeTodayIntent(),
            phrases: [
                "\(.applicationName) 오늘 요약",
                "\(.applicationName)로 오늘 요약해줘",
                "Summarize today in \(.applicationName)"
            ],
            shortTitle: "오늘 요약",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenVoiceInputIntent(),
            phrases: [
                "\(.applicationName) 음성 메모",
                "Voice memo in \(.applicationName)"
            ],
            shortTitle: "음성 메모",
            systemImageName: "mic.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}

// MARK: - Open Voice Input

/// "Dozy 음성 메모" → 앱을 전면으로 올리고 HomeView 의 음성 입력 시트를 연다.
/// CreateQuickEventIntent 와 같은 App Group 플래그 방식: perform 은 플래그만 켜고,
/// Dozy_AIApp 이 active 전환 시 플래그를 소비해 `.dozyOpenVoiceInput` 을 post 한다.
struct OpenVoiceInputIntent: AppIntent {

    static var title: LocalizedStringResource = "음성 메모"
    static var description = IntentDescription("Dozy 를 열고 음성으로 메모를 남깁니다.")
    static var openAppWhenRun: Bool = true

    static let pendingFlagKey = "pendingVoiceInput"

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: AppIntentStore.appGroupID)?.set(true, forKey: Self.pendingFlagKey)
        return .result()
    }
}

// MARK: - Store Access

enum AppIntentStore {

    static let appGroupID = "group.com.dozy-ai.shared"

    /// AppCoordinator.setup() 이 등록하는 살아있는 컨테이너. 앱이 떠 있으면 이걸 써서
    /// HomeViewModel 이 들고 있는 WorkLog 와 같은 mainContext 를 공유한다 (stale 방지).
    private static weak var registered: DependencyContainer?

    static func register(_ container: DependencyContainer) {
        registered = container
    }

    @MainActor
    static func modelContainer() throws -> ModelContainer {
        if let registered { return registered.modelContainer }
        return try openSharedStore()
    }

    static var aiService: AIServiceProtocol {
        registered?.aiService ?? AIService()
    }

    /// 앱 컨테이너가 없을 때(백그라운드 Siri 호출) 위젯과 동일하게 App Group store 를 직접 연다.
    /// 위젯이 이미 부분 스키마로 같은 store 를 여는 선례가 있어 필요한 모델만 나열한다.
    private static func openSharedStore() throws -> ModelContainer {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("default.store") else {
            throw DozyError.dataNotFound
        }
        let schema = Schema([WorkLog.self, TodayEventCache.self])
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// 오늘 WorkLog 를 찾고 없으면 만들어 insert. 날짜 조건은 WorkLogRepository.fetchLog 와 동일.
    @MainActor
    static func todayLog(in context: ModelContext) throws -> WorkLog {
        let start = Date().startOfDay
        let end = Date().startOfNextDay
        let descriptor = FetchDescriptor<WorkLog>(
            predicate: #Predicate<WorkLog> { $0.date >= start && $0.date < end }
        )
        if let existing = try context.fetch(descriptor).first { return existing }
        let log = WorkLog(date: Date())
        context.insert(log)
        return log
    }

    /// 위젯 캐시에서 오늘 일정을 읽는다. 메인 앱이 마지막으로 머지해 둔 Apple+Google+Dozy+공휴일
    /// 통합본이라 EventKit/Google 인증 없이 바로 쓸 수 있다.
    /// - 빈 배열: 오늘 일정 없음 (upsert 가 매번 기존 row 를 지우고 다시 쓰므로 신뢰 가능)
    /// - nil: cachedAt 이 오늘 이전 → 어제 데이터. 호출자가 "앱을 열어달라" 안내.
    @MainActor
    static func todayCachedEvents(in context: ModelContext) throws -> [TodayEventCache]? {
        let rows = try context.fetch(
            FetchDescriptor<TodayEventCache>(sortBy: [SortDescriptor(\.startDate)])
        )
        if rows.isEmpty { return [] }
        guard let latest = rows.map(\.cachedAt).max(), latest >= Date().startOfDay else { return nil }
        return rows
    }
}
