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
    @Published var dozyEventsByID: [String: DozyEvent] = [:]
    @Published var completionsByID: [String: Bool] = [:]
    @Published var isLoading = false

    /// 로그인 상태. coordinator 가 authViewModel.state 를 mirror 해서 설정.
    /// false 가 되면 fetch 를 막고 즉시 캐시 비움 — 메뉴바에 이전 사용자 일정이 남지 않게.
    @Published var isSignedIn: Bool = false {
        didSet {
            guard oldValue != isSignedIn else { return }
            if isSignedIn {
                loadTodayData()
            } else {
                todayEvents = []
                dozyEventsByID = [:]
                completionsByID = [:]
                isLoading = false
            }
        }
    }

    private let fetchCalendarEventUseCase: FetchCalendarEventUseCase
    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let fetchEventCompletionsUseCase: FetchEventCompletionsUseCase
    private let toggleDozyEventCompletionUseCase: ToggleDozyEventCompletionUseCase
    private let toggleCalendarEventCompletionUseCase: ToggleCalendarEventCompletionUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed

    var currentEvent: CalendarEvent? {
        let now = Date()
        return todayEvents.first { !$0.isAllDay && $0.startDate <= now && $0.endDate > now }
    }
    
    var upcomingEvent: CalendarEvent? {
        guard currentEvent == nil else { return nil }
        let now = Date()
        return todayEvents.first { !$0.isAllDay && $0.startDate > now }
    }
    
    // 메뉴바 리스트 표시용, 미완료 -> 완료 순. 같은 그룹 내에서는 시작 시각 오름차순
    var sortedEventsForDisplay: [CalendarEvent] {
        todayEvents.sorted { a, b in
            let ac = completionsByID[a.id] == true
            let bc = completionsByID[b.id] == true
            if ac != bc { return !ac }
            return a.startDate < b.startDate
        }
    }

    /// 체크되지 않은 오늘 일정 — 시간 경과와 무관. 사용자 멘탈 모델은
    /// "체크 안 한 = 남은" 이므로 endDate 시점 비교는 하지 않는다.
    var remainingEvents: [CalendarEvent] {
        todayEvents.filter { completionsByID[$0.id] != true }
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
        self.fetchCalendarEventUseCase = container.fetchCalendarEventUseCase
        self.fetchDozyEventsUseCase = container.fetchDozyEventsUseCase
        self.fetchEventCompletionsUseCase = container.fetchEventCompletionsUseCase
        self.toggleDozyEventCompletionUseCase = container.toggleDozyEventCompletionUseCase
        self.toggleCalendarEventCompletionUseCase = container.toggleCalendarEventCompletionUseCase

        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadTodayData() }
            .store(in: &cancellables)

        // 다른 화면에서 일정 토글한 변경분만 가볍게 반영. 자기-트리거는 object 식별로 무시.
        NotificationCenter.default.publisher(for: .dozyEventChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                if (note.object as AnyObject?) === self { return }
                self.loadCompletions(for: self.todayEvents.map(\.id), on: Date())
            }
            .store(in: &cancellables)

        // 일정 자체가 만들어졌거나 지워졌을 때 — 리스트 통째 재로드.
        NotificationCenter.default.publisher(for: .dozyEventListChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadTodayData() }
            .store(in: &cancellables)
    }

    // MARK: - Load

    func loadTodayData() {
        // 로그아웃 상태에선 fetch 자체를 막고 빈 상태 유지.
        guard isSignedIn else {
            todayEvents = []
            dozyEventsByID = [:]
            completionsByID = [:]
            isLoading = false
            return
        }
        isLoading = true
        let today = Date()

        // CompositeCalendarSerivce 가 Apple/Dozy(/Google) 머지된 [CalendarEvent] 를 반환.
        // dozyEventsByID 는 비반복 Dozy 일정 토글(직접 isCompleted 변경) 시 필요.
        Publishers.Zip(
            fetchCalendarEventUseCase.execute(for: today),
            fetchDozyEventsUseCase.execute(for: today)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] _ in self?.isLoading = false },
            receiveValue: { [weak self] events, dozyEvents in
                guard let self else { return }
                var byID: [String: DozyEvent] = [:]
                for d in dozyEvents { byID[d.id] = d }
                self.dozyEventsByID = byID

                let sorted = events.sorted { $0.startDate < $1.startDate }
                self.todayEvents = sorted
                self.loadCompletions(for: sorted.map(\.id), on: today)
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Toggle

    func toggleCompletion(for event: CalendarEvent) {
        let today = Date()

        if event.source == .dozy {
            guard let dozy = dozyEventsByID[event.id] else { return }
            if dozy.recurrenceRule == "none" {
                // UseCase 내부에서 toggle 하므로 호출부에서 따로 뒤집지 않음.
                toggleDozyEventCompletionUseCase.execute(dozy)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                        self?.broadcastCompletionChange()
                    })
                    .store(in: &cancellables)
                completionsByID[event.id] = dozy.isCompleted
                return
            }
        }

        toggleCalendarEventCompletionUseCase.execute(eventID: event.id, eventDate: today)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] newValue in
                    self?.completionsByID[event.id] = newValue
                    self?.broadcastCompletionChange()
                }
            )
            .store(in: &cancellables)
    }

    private func broadcastCompletionChange() {
        NotificationCenter.default.post(name: .dozyEventChanged, object: self)
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
                receiveValue: { [weak self] compositeMap in
                    guard let self else { return }
                    // composite key → simple eventID 변환 + Dozy 비반복 머지.
                    let dayStart = Calendar.current.startOfDay(for: date)
                    let suffix = "_\(Int(dayStart.timeIntervalSince1970))"
                    var simple: [String: Bool] = [:]
                    for (key, isCompleted) in compositeMap where isCompleted {
                        if key.hasSuffix(suffix) {
                            let eventID = String(key.dropLast(suffix.count))
                            simple[eventID] = true
                        }
                    }
                    for (id, dozy) in self.dozyEventsByID where dozy.recurrenceRule == "none" && dozy.isCompleted {
                        simple[id] = true
                    }
                    self.completionsByID = simple
                }
            )
            .store(in: &cancellables)
    }
}
