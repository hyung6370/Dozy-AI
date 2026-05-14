//
//  DependencyContainer.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - DI]
//  앱의 모든 의존성을 한 곳에서 조립합니다.
//  - ModelContainer를 직접 소유 (SwiftData 책임)
//  - Service, Repository, UseCase를 lazy로 초기화
//  - ViewModel은 UseCase만 받고 Service·Repository는 알지 못함

import Foundation
import Combine
import SwiftData

final class DependencyContainer: ObservableObject {

    // MARK: - SwiftData

    let modelContainer: ModelContainer

    // MARK: - Services (Data Layer)
    //
    // iOS 전용 서비스는 Google/Naver OAuth SDK에 의존하거나 CompositeCalendarSerivce
    // 처럼 Google 경로를 엮어 쓴다. macOS 버전에서는 이 묶음을 `#if os(iOS)` 블록으로
    // 격리하고, 공통 서비스(Apple EventKit 기반 CalendarService, DozyCalendarService
    // 등)만 공유한다. macOS Presentation은 M4 이후 여기에 플랫폼별 조립을 추가한다.

    lazy var reminderService: ReminderServiceProtocol = ReminderService()
    lazy var notificationService: NotificationServiceProtocol = NotificationService()
    lazy var cancelNotificationUseCase = CancelNotificationUseCase(service: notificationService)
    lazy var aiService: AIServiceProtocol = AIService()
    lazy var sharedCalendarService: SharedCalendarServiceProtocol = SharedCalendarService()
    lazy var authService = AuthService()
    lazy var sharedCalendarRealtimeService = SharedCalendarRealtimeService(
        modelContext: modelContainer.mainContext,
        notificationRepository: notificationRepository
    )
    lazy var calendarSourceManager = CalendarSourceManager()
    lazy var calendarVisibilityFilter = CalendarVisibilityFilter()
    lazy var patternAnalysisService = PatternAnalysisService()

    private lazy var appleCalendarService = CalendarService()
    private lazy var dozyCalendarService = DozyCalendarService(repository: dozyEventRepository)
    private lazy var holidayService = HolidayService()

    var appleCalendarServiceForSettings: CalendarService { appleCalendarService }
    
    lazy var calendarService: CompositeCalendarSerivce = {
        #if os(iOS)
        return CompositeCalendarSerivce(
            appleService: appleCalendarService,
            googleService: googleCalendarService,
            dozyService: dozyCalendarService,
            holidayService: holidayService,
            sourceManager: calendarSourceManager
        )
        #else
        return CompositeCalendarSerivce(
            appleService: appleCalendarService,
            dozyService: dozyCalendarService,
            holidayService: holidayService,
            sourceManager: calendarSourceManager
        )
        #endif
    }()
    
    #if os(iOS)
    lazy var scheduleNotificationUseCase = ScheduleNotificationUseCase(service: notificationService, notificationRepository: notificationRepository)
    lazy var googleSignInService = GoogleSignInService()
    lazy var naverSignInService = NaverSignInService()
    private lazy var googleCalendarService = GoogleCalendarService(signInService: googleSignInService)
    lazy var externalMirrorSyncService = ExternalMirrorSyncService(
        repository: dozyEventRepository,
        appleService: appleCalendarService,
        googleService: googleCalendarService,
        sourceManager: calendarSourceManager
    )
    #endif

    // MARK: - Repository (Data Layer)

    lazy var workLogRepository: WorkLogRepositoryProtocol = WorkLogRepository(modelContainer: modelContainer)
    lazy var dozyEventRepository: DozyEventRepositoryProtocol = DozyEventRepository(modelContainer: modelContainer)
    lazy var eventCompletionRepository: EventCompletionRepositoryProtocol = EventCompletionRepository(modelContainer: modelContainer)
    lazy var notificationRepository = NotificationRepository(modelContainer: modelContainer)
    lazy var eventDisplaySettingsRepository = EventDisplaySettingsRepository(modelContainer: modelContainer)

    // MARK: - UseCases (Domain Layer)

    lazy var saveWorkLogUseCase = SaveWorkLogUseCase(repository: workLogRepository)
    lazy var generateDailySummaryUseCase = GenerateDailySummaryUseCase(aiService: aiService, repository: workLogRepository)
    lazy var fetchRecentLogsUseCase = FetchRecentLogsUseCase(repository: workLogRepository)
    lazy var fetchDozyEventsUseCase = FetchDozyEventsUseCase(repository: dozyEventRepository)
    lazy var createDozyEventUseCase = CreateDozyEventUseCase(repository: dozyEventRepository)
    lazy var updateDozyEventUseCase = UpdateDozyEventUseCase(repository: dozyEventRepository)
    lazy var deleteDozyEventUseCase = DeleteDozyEventUseCase(repository: dozyEventRepository)
    lazy var toggleDozyEventCompletionUseCase = ToggleDozyEventCompletionUseCase(repository: dozyEventRepository)
    lazy var mirrorExternalEventUseCase = MirrorExternalEventUseCase(repository: dozyEventRepository)
    lazy var toggleCalendarEventCompletionUseCase = ToggleCalendarEventCompletionUseCase(repository: eventCompletionRepository)
    lazy var fetchEventCompletionsUseCase = FetchEventCompletionsUseCase(repository: eventCompletionRepository)
    lazy var fetchDozyEventsForPeriodUseCase = FetchDozyEventsForPeriodUseCase(repository: dozyEventRepository)
    lazy var fetchEventCompletionsForPeriodUseCase = FetchEventCompletionsForPeriodUseCase(repository: eventCompletionRepository)
    lazy var createSharedCalendarUseCase = CreateSharedCalendarUseCase(service: sharedCalendarService)
    lazy var joinSharedCalendarUseCase = JoinSharedCalendarUseCase(service: sharedCalendarService)
    lazy var leaveSharedCalendarUseCase = LeaveSharedCalendarUseCase(service: sharedCalendarService)
    lazy var regenerateSharedCalendarInviteCodeUseCase = RegenerateSharedCalendarInviteCodeUseCase(service: sharedCalendarService)
    lazy var updateSharedCalendarNicknameUseCase = UpdateSharedCalendarNicknameUseCase(service: sharedCalendarService)

    #if os(iOS)
    // FetchTodayDataUseCase 는 iOS 의 Today 화면 전용 — reminderService 까지 묶어 쓰는데
    // macOS Today 는 MacHomeViewModel 에서 직접 calendarService 를 사용한다.
    lazy var fetchTodayDataUseCase = FetchTodayDataUseCase(calendarService: calendarService, reminderService: reminderService)
    #endif

    // 캘린더 이벤트 UseCase — calendarService(Composite) 만 의존하므로 iOS/macOS 공통.
    lazy var fetchCalendarEventUseCase = FetchCalendarEventUseCase(calendarService: calendarService)
    lazy var updateCalendarEventUseCase = UpdateCalendarEventUseCase(service: calendarService)
    lazy var deleteCalendarEventUseCase = DeleteCalendarEventUseCase(service: calendarService)
    lazy var fetchCalendarEventsForPeriodUseCase = FetchCalendarEventsForPeriodUseCase(calendarService: calendarService)

    // MARK: - Cancellables
    var notificationCancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        let schema = Schema([
            WorkLog.self, UserPattern.self, DozyEvent.self,
            EventCompletion.self, NotificationRecord.self,
            EventDisplaySettings.self, UserCategory.self,
            TodayEventCache.self
        ])

        // 위젯 / 메인 앱이 동일 SwiftData store 를 보도록 App Group container 안에 저장.
        // 기존 사용자가 default 위치 (Application Support) 에 데이터를 가지고 있다면 첫
        // 부팅 시 새 위치로 이전.
        Self.migrateStoreToAppGroupIfNeeded()
        let storeURL = Self.appGroupStoreURL

        do {
            let config = ModelConfiguration(schema: schema, url: storeURL)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 스키마 변경으로 인한 스토어 호환 불가 시 스토어 재생성
            // 로그인 사용자는 Supabase에서 데이터 재동기화됨
            Self.destroyLocalStore()
            do {
                let config = ModelConfiguration(schema: schema, url: storeURL)
                self.modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("SwiftData ModelContainer 초기화 실패: \(error)")
            }
        }
        seedDefaultCategoriesIfNeeded()
    }

    // MARK: - App Group Store

    /// 위젯 extension 과 공유할 App Group identifier.
    /// Apple Developer Portal 에 등록된 동일 이름이어야 함.
    private static let appGroupID = "group.com.dozy-ai.shared"

    /// App Group container 안의 SwiftData store URL.
    /// `default.store` 라는 파일명은 SwiftData 가 ModelConfiguration(schema:) 의 기본값과 일치
    /// 시켜 store 호환성을 유지하기 위한 의도적 선택.
    private static var appGroupStoreURL: URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            // App Group entitlement 누락 / 등록 실패 — 디버깅을 위해 명시적 fatal.
            // Release 환경에서 이 분기에 도달하면 Provisioning Profile 문제.
            fatalError("App Group container 접근 실패. entitlement (\(appGroupID)) 확인 필요.")
        }
        return container.appendingPathComponent("default.store")
    }

    /// 기존 사용자의 default Application Support store 를 App Group container 로 이전.
    /// 한 번만 실행 (`hasMigratedToAppGroup` 플래그). 마이그레이션 실패해도 앱 동작에는
    /// 영향 없음 — store URL 이 새 위치라 첫 실행으로 인식, 로그인 사용자는 Supabase 에서 재동기화.
    private static let hasMigratedToAppGroupKey = "app.hasMigratedStoreToAppGroup_v1"

    private static func migrateStoreToAppGroupIfNeeded() {
        // 이미 마이그레이션 완료 → skip.
        if UserDefaults.standard.bool(forKey: hasMigratedToAppGroupKey) { return }

        let fm = FileManager.default
        guard let oldAppSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let newContainer = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        // SwiftData 가 만드는 파일은 store + WAL + SHM 셋. 기본 파일명은 default.store.
        let suffixes = [".store", ".store-shm", ".store-wal",
                        ".sqlite", ".sqlite-shm", ".sqlite-wal"]
        let oldFiles = (try? fm.contentsOfDirectory(at: oldAppSupport,
                                                    includingPropertiesForKeys: nil)) ?? []
        let storeFiles = oldFiles.filter { url in
            suffixes.contains(where: { url.lastPathComponent.hasSuffix($0) })
        }

        // 이전 대상 없음 → 신규 사용자. 플래그만 set 하고 종료.
        guard !storeFiles.isEmpty else {
            UserDefaults.standard.set(true, forKey: hasMigratedToAppGroupKey)
            return
        }

        var anyCopySucceeded = false
        for src in storeFiles {
            let dst = newContainer.appendingPathComponent(src.lastPathComponent)
            // 대상 파일이 이미 있다면 (예: 부분 마이그레이션) 건드리지 않음 — 안전 우선.
            if fm.fileExists(atPath: dst.path) { continue }
            do {
                try fm.copyItem(at: src, to: dst)
                anyCopySucceeded = true
            } catch {
                // 개별 파일 실패는 무시 — 모든 파일 못 옮겨도 main store 만 잘 옮겨졌으면 됨.
                continue
            }
        }

        // 마이그레이션 시도 결과와 무관하게 플래그 set — 두 번 다시 안 시도.
        // anyCopySucceeded == false 이면 원본 store 가 손상됐거나 권한 문제. 어느 쪽이든
        // 다음 부팅에 새 App Group store 로 fresh 시작 (Supabase 동기화로 복원).
        UserDefaults.standard.set(true, forKey: hasMigratedToAppGroupKey)
        _ = anyCopySucceeded   // logging hook 자리, 현재 미사용.

        // 원본 파일은 즉시 삭제하지 않음 — 마이그레이션 검증 기간 (2~3개 release) 동안 유지하여
        // 문제 발견 시 복구 가능. 추후 cleanup PR 에서 일괄 정리.
    }

    private static func destroyLocalStore() {
        // App Group container 의 store 만 삭제 (default Application Support 의 옛 파일은
        // 마이그레이션 검증 기간 동안 유지).
        let fm = FileManager.default
        guard let container = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let storeExtensions = [".store", ".store-shm", ".store-wal",
                               ".sqlite", ".sqlite-shm", ".sqlite-wal",
                               ".db", ".db-shm", ".db-wal"]
        let files = (try? fm.contentsOfDirectory(at: container, includingPropertiesForKeys: nil)) ?? []
        for file in files where storeExtensions.contains(where: { file.lastPathComponent.hasSuffix($0) }) {
            try? fm.removeItem(at: file)
        }
    }

    /// 앱이 최초 실행(또는 재설치 후 재실행)일 때 기본 카테고리를 시드합니다.
    /// Keychain 플래그를 이용해 재설치 여부를 감지합니다.
    /// - 최초 설치: 플래그 없음 + SwiftData 비어있음 → 시드 후 플래그 저장
    /// - 재설치: 플래그 있음 + SwiftData 비어있음 → 시드 건너뜀 (Supabase에서 동기화됨)
    /// - 일반 재실행: SwiftData에 이미 카테고리 있음 → 시드 건너뜀
    private static let hasSeededCategoriesKey = "app.hasSeededCategories"

    private func seedDefaultCategoriesIfNeeded() {
        let context = modelContainer.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<UserCategory>())) ?? 0
        guard count == 0 else { return }

        // 재설치 감지: Keychain 플래그가 이미 있으면 이전에 시드한 적 있음
        // → 사용자 카테고리는 Supabase 동기화로 복원되므로 재시드 불필요
        if KeychainService.load(forKey: Self.hasSeededCategoriesKey) != nil {
            return
        }

        let defaults: [(String, String, String)] = [
            ("일반", "📌", "#8E8E93")
        ]
        for (i, (name, emoji, color)) in defaults.enumerated() {
            context.insert(UserCategory(name: name, emoji: emoji, colorHex: color, order: i))
        }
        try? context.save()
        KeychainService.save("1", forKey: Self.hasSeededCategoriesKey)
    }
}
