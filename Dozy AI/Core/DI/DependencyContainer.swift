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

    // MARK: - SwiftData (소유)

    let modelContainer: ModelContainer

    // MARK: - Services (Data Layer)

    lazy var calendarService: CalendarServiceProtocol = CompositeCalendarSerivce(
        appleService: appleCalendarService,
        googleService: googleCalendarService,
        naverService: naverCalendarService,
        dozyService: dozyCalendarService,
        sourceManager: calendarSourceManager
    )
    lazy var reminderService: ReminderServiceProtocol = ReminderService()
    lazy var aiService: AIServiceProtocol = AIService()
    lazy var googleSignInService = GoogleSignInService()
    lazy var naverSignInService = NaverSignInService()
    lazy var calendarSourceManager = CalendarSourceManager()
    
    private lazy var appleCalendarService: CalendarServiceProtocol = CalendarService()
    private lazy var googleCalendarService = GoogleCalendarService(signInService: googleSignInService)
    private lazy var naverCalendarService = NaverCalendarService(signInService: naverSignInService)
    private lazy var dozyCalendarService = DozyCalendarService(repository: dozyEventRepository)

    // MARK: - Repository (Data Layer)

    lazy var workLogRepository: WorkLogRepositoryProtocol = WorkLogRepository(modelContainer: modelContainer)
    lazy var dozyEventRepository: DozyEventRepositoryProtocol = DozyEventRepository(modelContainer: modelContainer)

    // MARK: - UseCases (Domain Layer)

    lazy var fetchTodayDataUseCase = FetchTodayDataUseCase(
        calendarService: calendarService,
        reminderService: reminderService
    )

    lazy var saveWorkLogUseCase = SaveWorkLogUseCase(
        repository: workLogRepository
    )

    lazy var generateDailySummaryUseCase = GenerateDailySummaryUseCase(
        aiService: aiService,
        repository: workLogRepository
    )

    lazy var fetchRecentLogsUseCase = FetchRecentLogsUseCase(
        repository: workLogRepository
    )
    
    lazy var fetchCalendarEventsUseCase = FetchCalendarEventUseCase(calendarService: calendarService)
    lazy var fetchDozyEventsUseCase = FetchDozyEventsUseCase(repository: dozyEventRepository)
    lazy var createDozyEventUseCase = CreateDozyEventUseCase(repository: dozyEventRepository)
    lazy var updateDozyEventUseCase = UpdateDozyEventUseCase(repository: dozyEventRepository)
    lazy var deleteDozyEventUseCase = DeleteDozyEventUseCase(repository: dozyEventRepository)

    // MARK: - Init

    init() {
        do {
            let schema = Schema([WorkLog.self, UserPattern.self, DozyEvent.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer 초기화 실패: \(error)")
        }
    }
}
