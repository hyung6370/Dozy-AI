//
//  HomeViewModel.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    
    // MARK: - Published State (View가 관찰)
    @Published var todayEvents: [CalendarEvent] = []
    @Published var completedTasks: [TaskItem] = []
    @Published var pendingTasks: [TaskItem] = []
    @Published var todayLog: WorkLog?
    @Published var recentLogs: [WorkLog] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false
    
    // MARK: - Computed Properties
    var todayDateString: String {
        Date().formattedKorean
    }
    
    var eventCount: Int { todayEvents.count }
    var completedCount: Int { completedTasks.count }
    var pendingCount: Int { pendingTasks.count }
    
    var hasData: Bool {
        !todayEvents.isEmpty || !completedTasks.isEmpty
    }
    
    // MARK: - Dependencies
    private let calendarService: CalendarServiceProtocol
    private let reminderService: ReminderServiceProtocol
    private let repository: WorkLogRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init(
        calendarService: CalendarServiceProtocol,
        reminderService: ReminderServiceProtocol,
        repository: WorkLogRepositoryProtocol
    ) {
        self.calendarService = calendarService
        self.reminderService = reminderService
        self.repository = repository
    }
    
    /// DependencyContainer에서 편리하게 생성
    convenience init(container: DependencyContainer) {
        self.init(
            calendarService: container.calendarService,
            reminderService: container.reminderService,
            repository: container.workLogRepository
        )
    }
    
    // MARK: - 데이터 로드
    
    /// 오늘의 모든 데이터를 한 번에 로드
    func loadTodayData() {
        isLoading = true
        errorMessage = nil
        
        // 1) 캘린더 이벤트 + 완료된 리마인더 + 미완료 리마인더를 동시에 가져옴
        //    CombineLatest3으로 세 퍼블리셔가 모두 완료되면 결과를 받음
        Publishers.CombineLatest3(
            calendarService.fetchTodayEvents(),
            reminderService.fetchCompletedReminders(for: Date()),
            reminderService.fetchPendingReminders()
        )
        .receive(on: DispatchQueue.main)  // UI 업데이트는 메인 스레드에서
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] events, completed, pending in
                self?.todayEvents = events
                self?.completedTasks = completed
                self?.pendingTasks = pending
                
                // WorkLog 생성 또는 업데이트
                self?.updateTodayLog(events: events, tasks: completed)
            }
        )
        .store(in: &cancellables)
        
        // 2) 최근 7일간 로그도 별도로 로드
        loadRecentLogs()
    }
    
    /// 최근 로그 목록 조회
    func loadRecentLogs() {
        repository.fetchRecentLogs(days: 7)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] logs in
                    self?.recentLogs = logs
                }
            )
            .store(in: &cancellables)
    }
    
    /// 메모 추가
    func addMemo(_ text: String) {
        guard let log = todayLog else { return }
        log.addMemo(text)
        
        repository.save(log)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private
    
    /// 오늘의 WorkLog를 생성하거나 업데이트
    private func updateTodayLog(events: [CalendarEvent], tasks: [TaskItem]) {
        repository.fetchLog(for: Date())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] existingLog in
                    guard let self else { return }
                    
                    let log = existingLog ?? WorkLog(date: Date())
                    log.populate(with: events)
                    log.populate(with: tasks)
                    self.todayLog = log
                    
                    self.repository.save(log)
                        .sink(receiveCompletion: { _ in }, receiveValue: { })
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
    }
    
    /// 에러 처리 통합
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
