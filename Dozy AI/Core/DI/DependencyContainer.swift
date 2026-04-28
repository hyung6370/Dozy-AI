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
    lazy var sharedCalendarRealtimeService = SharedCalendarRealtimeService(modelContext: modelContainer.mainContext)
    lazy var calendarSourceManager = CalendarSourceManager()
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
            EventDisplaySettings.self, UserCategory.self
        ])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 스키마 변경으로 인한 스토어 호환 불가 시 스토어 재생성
            // 로그인 사용자는 Supabase에서 데이터 재동기화됨
            Self.destroyLocalStore()
            do {
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                self.modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("SwiftData ModelContainer 초기화 실패: \(error)")
            }
        }
        seedDefaultCategoriesIfNeeded()
    }

    private static func destroyLocalStore() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeExtensions = [".store", ".store-shm", ".store-wal",
                               ".sqlite", ".sqlite-shm", ".sqlite-wal",
                               ".db", ".db-shm", ".db-wal"]
        let files = (try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)) ?? []
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
