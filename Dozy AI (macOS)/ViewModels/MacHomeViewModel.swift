//
//  MacHomeViewModel.swift
//  Dozy AI (macOS)
//
//  M4.4 — Today 뷰 전용 ViewModel. 현재는 Supabase DozyEvent 만 취급하며
//  Apple/Google/Naver 네이티브 캘린더 이벤트는 후속 페이즈에서 추가한다.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class MacHomeViewModel: ObservableObject {

    // MARK: - Published

    @Published var todayEvents: [CalendarEvent] = []
    @Published var completionsByEventID: [String: Bool] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Deps

    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let fetchEventCompletionsUseCase: FetchEventCompletionsUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed

    var todayDateString: String { Date().formattedKorean }

    var eventCount: Int { todayEvents.count }

    var completedCount: Int {
        todayEvents.filter { completionsByEventID[$0.id] == true }.count
    }

    var pendingCount: Int {
        todayEvents.filter { completionsByEventID[$0.id] != true }.count
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "좋은 아침이에요 ☀️"
        case 12..<18: return "좋은 오후예요 🌤️"
        case 18..<21: return "좋은 저녁이에요 🌙"
        default:      return "안녕하세요 🌟"
        }
    }

    var currentEvent: CalendarEvent? {
        let now = Date()
        return todayEvents.first { $0.startDate <= now && $0.endDate > now }
    }

    var upcomingEvent: CalendarEvent? {
        guard currentEvent == nil else { return nil }
        let now = Date()
        return todayEvents.first { $0.startDate > now }
    }

    // MARK: - Init

    init(container: DependencyContainer) {
        self.fetchDozyEventsUseCase = container.fetchDozyEventsUseCase
        self.fetchEventCompletionsUseCase = container.fetchEventCompletionsUseCase

        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadTodayData() }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func loadTodayData() {
        isLoading = true
        errorMessage = nil
        let today = Date()

        fetchDozyEventsUseCase.execute(for: today)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] dozyEvents in
                    guard let self else { return }
                    let events = dozyEvents
                        .map { $0.toCalendarEvent(for: today) }
                        .sorted { $0.startDate < $1.startDate }
                    self.todayEvents = events
                    self.loadCompletions(for: events.map(\.id), on: today)
                }
            )
            .store(in: &cancellables)
    }

    private func loadCompletions(for ids: [String], on date: Date) {
        guard !ids.isEmpty else {
            completionsByEventID = [:]
            return
        }
        fetchEventCompletionsUseCase.execute(for: ids, on: date)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] map in
                    self?.completionsByEventID = map
                }
            )
            .store(in: &cancellables)
    }
}
