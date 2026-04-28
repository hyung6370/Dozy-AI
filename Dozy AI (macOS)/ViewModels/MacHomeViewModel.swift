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
    @Published var mySharedCalendars: [SharedCalendar] = []
    @Published var todayLog: WorkLog?
    @Published var dailySummary: DailySummary?
    @Published var isLoading = false
    @Published var isSummarizing = false
    @Published var errorMessage: String?
    @Published var showSuccessAnimation = false

    // MARK: - Deps

    private let fetchDozyEventsUseCase: FetchDozyEventsUseCase
    private let fetchCalendarEventUseCase: FetchCalendarEventUseCase
    private let fetchEventCompletionsUseCase: FetchEventCompletionsUseCase
    private let createDozyEventUseCase: CreateDozyEventUseCase
    private let updateDozyEventUseCase: UpdateDozyEventUseCase
    private let deleteDozyEventUseCase: DeleteDozyEventUseCase
    private let toggleDozyEventCompletionUseCase: ToggleDozyEventCompletionUseCase
    private let toggleCalendarEventCompletionUseCase: ToggleCalendarEventCompletionUseCase
    private let saveWorkLogUseCase: SaveWorkLogUseCase
    private let generateDailySummaryUseCase: GenerateDailySummaryUseCase
    private let sharedCalendarService: SharedCalendarServiceProtocol
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

    var hasData: Bool {
        !todayEvents.isEmpty || !(todayLog?.memos ?? []).isEmpty
    }

    var hasSummary: Bool {
        dailySummary != nil || !(todayLog?.aiSummary.isEmpty ?? true)
    }

    var scorePercentage: Int {
        guard let score = dailySummary?.productivityScore else { return 0 }
        return Int(score * 100)
    }

    // MARK: - Init

    init(container: DependencyContainer) {
        self.fetchDozyEventsUseCase = container.fetchDozyEventsUseCase
        self.fetchCalendarEventUseCase = container.fetchCalendarEventUseCase
        self.fetchEventCompletionsUseCase = container.fetchEventCompletionsUseCase
        self.createDozyEventUseCase = container.createDozyEventUseCase
        self.updateDozyEventUseCase = container.updateDozyEventUseCase
        self.deleteDozyEventUseCase = container.deleteDozyEventUseCase
        self.toggleDozyEventCompletionUseCase = container.toggleDozyEventCompletionUseCase
        self.toggleCalendarEventCompletionUseCase = container.toggleCalendarEventCompletionUseCase
        self.saveWorkLogUseCase = container.saveWorkLogUseCase
        self.generateDailySummaryUseCase = container.generateDailySummaryUseCase
        self.sharedCalendarService = container.sharedCalendarService

        NotificationCenter.default.publisher(for: .dozyDataSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadTodayData() }
            .store(in: &cancellables)

        // 다른 화면(Calendar / MenuBar)에서 일정 토글한 변경분만 가볍게 반영.
        // 자기 자신이 post 한 알림(object === self)은 무시 — 이미 optimistic 으로 반영됐고
        // 자기-트리거 reload 가 race 로 optimistic 값을 덮어쓰는 현상 방지.
        NotificationCenter.default.publisher(for: .dozyEventChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                if (note.object as AnyObject?) === self { return }
                self.loadCompletions(for: self.todayEvents.map(\.id), on: Date())
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func loadTodayData() {
        isLoading = true
        errorMessage = nil
        let today = Date()

        loadMySharedCalendars()

        // Apple/Dozy(/Google) 머지된 [CalendarEvent] 와 편집용 [DozyEvent] 를 병렬로 받음.
        Publishers.Zip(
            fetchCalendarEventUseCase.execute(for: today),
            fetchDozyEventsUseCase.execute(for: today)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            },
            receiveValue: { [weak self] allEvents, dozyEvents in
                guard let self else { return }
                var byID: [String: DozyEvent] = [:]
                for d in dozyEvents { byID[d.id] = d }
                self.dozyEventsByID = byID

                let events = allEvents.sorted { a, b in
                    if a.isPinned != b.isPinned { return a.isPinned }
                    return a.startDate < b.startDate
                }
                self.todayEvents = events
                self.loadCompletions(for: events.map(\.id), on: today)
                self.persistTodayLog(events: events)
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Event CRUD

    /// 일정 완료 토글. iOS 패턴 — Dozy 비반복은 DozyEvent.isCompleted 직접 토글,
    /// Dozy 반복 / Apple / Google 은 EventCompletion 테이블에 (eventID, today) 단위로 저장.
    func toggleCompletion(for event: CalendarEvent) {
        let today = Date()

        if event.source == .dozy {
            guard let dozy = dozyEventsByID[event.id] else { return }
            if dozy.recurrenceRule == "none" {
                // ToggleDozyEventCompletionUseCase 가 내부에서 dozy.isCompleted.toggle() 후 save —
                // 호출부에서 따로 토글하면 두 번 뒤집어 no-op 이 된다. .execute 호출 직후 dozy 인스턴스는
                // 이미 새 값으로 동기 변경된 상태이므로 그 값을 그대로 optimistic UI 에 반영.
                toggleDozyEventCompletionUseCase.execute(dozy)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                        self?.broadcastCompletionChange()
                    })
                    .store(in: &cancellables)
                completionsByEventID[event.id] = dozy.isCompleted
                dozyEventsByID[event.id] = dozy   // @Published 트리거
                return
            }
        }

        // Dozy 반복 / Apple / Google — 모두 EventCompletion 테이블 사용
        toggleCalendarEventCompletionUseCase.execute(eventID: event.id, eventDate: today)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] newValue in
                    self?.completionsByEventID[event.id] = newValue
                    self?.broadcastCompletionChange()
                }
            )
            .store(in: &cancellables)
    }

    /// 토글 직후 — Insight VM / 다른 Today/MenuBar/Calendar 인스턴스가 듣는 가벼운 알림.
    /// `.dozyDataSyncCompleted` 와 달리 캐시 invalidate 없이 completion 만 재조회시키는 용도.
    /// object 에 self 를 실어서 자기 자신은 무시할 수 있게 한다 (optimistic 값 보호).
    private func broadcastCompletionChange() {
        NotificationCenter.default.post(name: .dozyEventChanged, object: self)
    }

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

    func deleteThisOccurrence(_ event: DozyEvent, date: Date) {
        let occStart = event.occurrenceStart(for: date) ?? Calendar.current.startOfDay(for: date)
        event.excludedDates.append(occStart)
        event.updatedAt = Date()
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func deleteFutureOccurrences(_ event: DozyEvent, from date: Date) {
        let cal = Calendar.current
        event.recurrenceEndDate = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))
        event.updatedAt = Date()
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    func saveMemos(for event: DozyEvent) {
        updateDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    func updateDisplaySettings(for event: CalendarEvent, priority: Int, isPinned: Bool, category: String?) {
        guard let dozy = dozyEventsByID[event.id] else { return }
        dozy.priority = priority
        dozy.isPinned = isPinned
        if let category {
            dozy.category = category
            if let ctx = dozy.modelContext,
               let cat = try? ctx.fetch(FetchDescriptor<UserCategory>()).first(where: { $0.name == category }) {
                dozy.colorHex = cat.colorHex
            }
        }
        dozy.updatedAt = Date()
        updateDozyEventUseCase.execute(dozy)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.loadTodayData()
            })
            .store(in: &cancellables)
    }

    // MARK: - Memo

    func addMemo(_ text: String) {
        guard let log = todayLog else { return }
        saveWorkLogUseCase.addMemo(text, to: log)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    func updateMemo(at index: Int, text: String) {
        guard let log = todayLog else { return }
        saveWorkLogUseCase.updateMemo(at: index, text: text, in: log)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    func deleteMemo(at index: Int) {
        guard let log = todayLog else { return }
        saveWorkLogUseCase.deleteMemo(at: index, in: log)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    // MARK: - AI 요약

    func generateAISummary() {
        guard hasData else {
            errorMessage = "요약할 데이터가 부족합니다."
            return
        }

        isSummarizing = true
        errorMessage = nil

        generateDailySummaryUseCase.execute(
            events: todayEvents,
            completedTasks: [],
            pendingTasks: [],
            memos: todayLog?.memos ?? [],
            completedEventCount: completedCount
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

    // MARK: - Shared Calendars

    private func loadMySharedCalendars() {
        sharedCalendarService.fetchMyCalendars()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] calendars in
                    self?.mySharedCalendars = calendars
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Private

    private func persistTodayLog(events: [CalendarEvent]) {
        saveWorkLogUseCase.execute(events: events, tasks: [])
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] log in
                    guard let self else { return }
                    self.todayLog = log
                    if !log.aiSummary.isEmpty {
                        self.dailySummary = DailySummary(
                            date: log.date,
                            summaryText: log.aiSummary,
                            highlights: log.highlights,
                            nextActions: log.nextActions,
                            detectedCategory: log.category,
                            productivityScore: log.productivityScore ?? 0,
                            totalEventMinutes: 0,
                            completedTaskCount: 0
                        )
                    }
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
                receiveValue: { [weak self] compositeMap in
                    guard let self else { return }
                    // EventCompletionRepository 는 composite key (`eventID_dayTimestamp`) 로
                    // 반환. 화면은 simple eventID 로 조회하므로 같은 날짜 안에서 dayTimestamp
                    // suffix 를 떼어내 simple eventID 로 재키잉.
                    let dayStart = Calendar.current.startOfDay(for: date)
                    let suffix = "_\(Int(dayStart.timeIntervalSince1970))"
                    var simple: [String: Bool] = [:]
                    for (key, isCompleted) in compositeMap where isCompleted {
                        if key.hasSuffix(suffix) {
                            let eventID = String(key.dropLast(suffix.count))
                            simple[eventID] = true
                        }
                    }
                    // Dozy 비반복 일정은 EventCompletion 테이블에 안 들어감 (DozyEvent.isCompleted 사용).
                    // 토글 직후 재로드 시 사라지지 않도록 dozyEventsByID 에서 머지.
                    for (id, dozy) in self.dozyEventsByID where dozy.recurrenceRule == "none" && dozy.isCompleted {
                        simple[id] = true
                    }
                    self.completionsByEventID = simple
                }
            )
            .store(in: &cancellables)
    }
}
