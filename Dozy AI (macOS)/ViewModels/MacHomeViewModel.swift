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
    @Published var dozyEventsByID: [String: DozyEvent] = [:]
    @Published var completionsByEventID: [String: Bool] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAnimation = false

    // MARK: - Deps

    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let fetchEventCompletionsUseCase: FetchEventCompletionsUseCase
    private let createDozyEventUseCase: CreateDozyEventUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let deleteDozyEventUseCase: DeleteDozyEventUseCase
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
        self.createDozyEventUseCase = container.createDozyEventUseCase
        self.updateDozyEventUseCase = container.updateDozyEventUseCase
        self.deleteDozyEventUseCase = container.deleteDozyEventUseCase

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
                    var byID: [String: DozyEvent] = [:]
                    for d in dozyEvents { byID[d.id] = d }
                    self.dozyEventsByID = byID

                    let events = dozyEvents
                        .map { $0.toCalendarEvent(for: today) }
                        .sorted { $0.startDate < $1.startDate }
                    self.todayEvents = events
                    self.loadCompletions(for: events.map(\.id), on: today)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Event CRUD

    /// 새 일정이면 create, 기존이면 update. Supabase 동기화 후 로컬 Today 재로드.
    func saveDozyEvent(_ event: DozyEvent) {
        let isNew = dozyEventsByID[event.id] == nil
        let publisher = isNew
            ? createDozyEventUseCase.execute(event)
            : updateDozyEventUseCase.execute(event)
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.loadTodayData()
                    if isNew { self?.showSuccessAnimation = true }
                }
            )
            .store(in: &cancellables)
    }

    func deleteDozyEvent(_ event: DozyEvent) {
        deleteDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.loadTodayData()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Private

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
