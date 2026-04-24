//
//  MacMenuBarViewModel.swift
//  Dozy AI (macOS)
//
//  M4.10 — 메뉴바 팝오버 전용 라이트웨이트 ViewModel.
//  오늘자 DozyEvent + 완료 상태만 페치. 메인 MacHomeViewModel 과 독립적이라
//  메인 윈도우가 닫혀 있어도 동작한다.
//

import Foundation
import Combine

@MainActor
final class MacMenuBarViewModel: ObservableObject {

    @Published var todayEvents: [CalendarEvent] = []
    @Published var completionsByID: [String: Bool] = [:]
    @Published var isLoading = false

    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let fetchEventCompletionsUseCase: FetchEventCompletionsUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed

    var currentEvent: CalendarEvent? {
        let now = Date()
        return todayEvents.first { $0.startDate <= now && $0.endDate > now }
    }

    var upcomingEvent: CalendarEvent? {
        guard currentEvent == nil else { return nil }
        let now = Date()
        return todayEvents.first { $0.startDate > now }
    }

    var remainingEvents: [CalendarEvent] {
        let now = Date()
        return todayEvents.filter { $0.endDate > now && completionsByID[$0.id] != true }
    }

    var remainingCount: Int { remainingEvents.count }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "좋은 아침이에요 ☀️"
        case 12..<18: return "좋은 오후예요 🌤️"
        case 18..<21: return "좋은 저녁이에요 🌙"
        default:      return "안녕하세요 🌟"
        }
    }

    var todayDateString: String { Date().formattedKorean }

    // MARK: - Init

    init(container: DependencyContainer) {
        self.fetchDozyEventsUseCase = container.fetchDozyEventsUseCase
        self.fetchEventCompletionsUseCase = container.fetchEventCompletionsUseCase

        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadTodayData() }
            .store(in: &cancellables)
    }

    // MARK: - Load

    func loadTodayData() {
        isLoading = true
        let today = Date()

        fetchDozyEventsUseCase.execute(for: today)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in self?.isLoading = false },
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
            completionsByID = [:]
            return
        }
        fetchEventCompletionsUseCase.execute(for: ids, on: date)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] map in
                    self?.completionsByID = map
                }
            )
            .store(in: &cancellables)
    }
}
