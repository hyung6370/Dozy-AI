//
//  HomeViewModel.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//
//  [Clean Architecture - MVVM]
//  ViewModel은 UseCase만 사용합니다.
//  Service나 Repository를 직접 참조하지 않습니다.

import Foundation
import Combine

final class HomeViewModel: ObservableObject {

    // MARK: - Published State

    @Published var todayEvents: [CalendarEvent] = []
    @Published var completedTasks: [TaskItem] = []
    @Published var pendingTasks: [TaskItem] = []
    @Published var todayLog: WorkLog?
    @Published var recentLogs: [WorkLog] = []

    @Published var dailySummary: DailySummary?
    @Published var isSummarizing = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false
    
    @Published var selectedSource: CalendarSource? = nil

    // MARK: - Computed Properties

    var todayDateString: String { Date().formattedKorean }
    var eventCount: Int { todayEvents.count }
    var completedCount: Int { completedTasks.count }
    var pendingCount: Int { pendingTasks.count }

    var hasData: Bool {
        !todayEvents.isEmpty || !completedTasks.isEmpty
    }

    var hasSummary: Bool {
        dailySummary != nil || !(todayLog?.aiSummary.isEmpty ?? true)
    }

    var scorePercentage: Int {
        guard let score = dailySummary?.productivityScore else { return 0 }
        return Int(score * 100)
    }
    
    // 활성 소스가 2개 이상일 때만 탭 표시
    var showSourceTabs: Bool {
        calendarSourceManager.enabledSources.count > 1
    }
    
    // 활성화된 소스 목록 (탭 생성용)
    var availableSources: [CalendarSource] {
        CalendarSource.allCases.filter { calendarSourceManager.isEnabled($0) }
    }
    
    // 선택된 탭에 따라 필터링
    var filteredEvents: [CalendarEvent] {
        guard let source = selectedSource else { return todayEvents }
        return todayEvents.filter { $0.source == source }
    }
    
    private let calendarSourceManager: CalendarSourceManager
    private let googleSignInService: GoogleSignInService

    // MARK: - Dependencies (UseCases만)

    private let fetchTodayDataUseCase: FetchTodayDataUseCase
    private let saveWorkLogUseCase: SaveWorkLogUseCase
    private let generateDailySummaryUseCase: GenerateDailySummaryUseCase
    private let fetchRecentLogsUseCase: FetchRecentLogsUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        fetchTodayDataUseCase: FetchTodayDataUseCase,
        saveWorkLogUseCase: SaveWorkLogUseCase,
        generateDailySummaryUseCase: GenerateDailySummaryUseCase,
        fetchRecentLogsUseCase: FetchRecentLogsUseCase,
        calendarSourceManager: CalendarSourceManager,
        googleSignInService: GoogleSignInService
    ) {
        self.fetchTodayDataUseCase = fetchTodayDataUseCase
        self.saveWorkLogUseCase = saveWorkLogUseCase
        self.generateDailySummaryUseCase = generateDailySummaryUseCase
        self.fetchRecentLogsUseCase = fetchRecentLogsUseCase
        self.calendarSourceManager = calendarSourceManager
        self.googleSignInService = googleSignInService
        
        googleSignInService.$isSignedIn
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadTodayData()
            }
            .store(in: &cancellables)
        
        calendarSourceManager.$enabledSources
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sources in
                guard let self else { return }
                if let selected = self.selectedSource, !sources.contains(selected) {
                    self.selectedSource = nil
                }
                self.loadTodayData()
            }
            .store(in: &cancellables)
    }

    convenience init(container: DependencyContainer) {
        self.init(
            fetchTodayDataUseCase: container.fetchTodayDataUseCase,
            saveWorkLogUseCase: container.saveWorkLogUseCase,
            generateDailySummaryUseCase: container.generateDailySummaryUseCase,
            fetchRecentLogsUseCase: container.fetchRecentLogsUseCase,
            calendarSourceManager: container.calendarSourceManager,
            googleSignInService: container.googleSignInService
        )
    }

    // MARK: - 데이터 로드

    func loadTodayData() {
        isLoading = true
        errorMessage = nil

        fetchTodayDataUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] result in
                    guard let self else { return }
                    self.todayEvents = result.events
                    self.completedTasks = result.completedTasks
                    self.pendingTasks = result.pendingTasks
                    self.persistTodayLog(events: result.events, tasks: result.completedTasks)
                }
            )
            .store(in: &cancellables)

        loadRecentLogs()
    }

    func loadRecentLogs() {
        fetchRecentLogsUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] logs in
                    self?.recentLogs = logs
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 메모 추가

    func addMemo(_ text: String) {
        guard let log = todayLog else { return }

        saveWorkLogUseCase.addMemo(text, to: log)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    // MARK: - AI 요약 생성

    func generateAISummary() {
        guard hasData else {
            errorMessage = "요약할 데이터가 부족합니다."
            return
        }

        isSummarizing = true
        errorMessage = nil

        generateDailySummaryUseCase.execute(
            events: todayEvents,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            memos: todayLog?.memos ?? []
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isSummarizing = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            },
            receiveValue: { [weak self] summary in
                self?.dailySummary = summary
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Private

    /// 오늘 WorkLog를 생성/업데이트하고 AI 요약이 있으면 복원합니다
    private func persistTodayLog(events: [CalendarEvent], tasks: [TaskItem]) {
        saveWorkLogUseCase.execute(events: events, tasks: tasks)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] log in
                    guard let self else { return }
                    self.todayLog = log
                    // 저장된 AI 요약이 있으면 복원
                    if !log.aiSummary.isEmpty {
                        self.restoreSummaryFromLog(log)
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func restoreSummaryFromLog(_ log: WorkLog) {
        let totalMinutes = todayEvents
            .filter { !$0.isAllDay }
            .reduce(0) { $0 + $1.durationMinutes }

        dailySummary = DailySummary(
            date: log.date,
            summaryText: log.aiSummary,
            highlights: log.highlights,
            nextActions: log.nextActions,
            detectedCategory: log.category,
            productivityScore: log.productivityScore ?? 0.0,
            totalEventMinutes: totalMinutes,
            completedTaskCount: log.completedTaskTitles.count
        )
    }

    private func handleError(_ error: DozyError) {
        switch error {
        case .calendarAccessDenied, .reminderAccessDenied:
            showPermissionAlert = true
            errorMessage = error.errorDescription
        default:
            errorMessage = error.errorDescription
        }
    }
}
