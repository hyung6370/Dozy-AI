//
//  SearchViewModelTests.swift
//  Dozy AITests
//
//  #72 — SearchViewModel 의 외부 일정 지연 조회 · 표시 설정 저장 · 메모 삭제 · 자연어 질의 흐름.
//

import XCTest
import Combine
@testable import Dozy_AI

private final class MockCalendarWriteService: CalendarWriteServiceProtocol {
    private(set) var updateCallCount = 0
    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError> {
        updateCallCount += 1
        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
    func deleteEvent(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError> {
        Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

private final class MockDisplaySettingsRepository: EventDisplaySettingsRepositoryProtocol {
    private(set) var saved: [(eventID: String, priority: Int, isPinned: Bool, category: String)] = []
    func save(eventID: String, priority: Int, isPinned: Bool, category: String) -> AnyPublisher<Void, Never> {
        saved.append((eventID, priority, isPinned, category))
        return Just(()).eraseToAnyPublisher()
    }
}

@MainActor
final class SearchViewModelTests: XCTestCase {

    private let now: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12))!

    private var vm: SearchViewModel!
    private var calendarService: MockPeriodCalendarService!
    private var dozyRepo: MockDozyEventRepository!
    private var workLogRepo: MockWorkLogRepository!
    private var displayRepo: MockDisplaySettingsRepository!
    private var parser: MockQueryParsingService!
    private var analytics: MockAnalyticsService!

    override func setUp() {
        super.setUp()
        calendarService = MockPeriodCalendarService()
        dozyRepo = MockDozyEventRepository()
        workLogRepo = MockWorkLogRepository()
        displayRepo = MockDisplaySettingsRepository()
        parser = MockQueryParsingService()
        analytics = MockAnalyticsService()
        let fixedNow = now
        vm = SearchViewModel(
            fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase(calendarService: calendarService),
            updateDozyEventUseCase: UpdateDozyEventUseCase(repository: dozyRepo),
            updateCalendarEventUseCase: UpdateCalendarEventUseCase(service: MockCalendarWriteService()),
            saveEventDisplaySettingsUseCase: SaveEventDisplaySettingsUseCase(repository: displayRepo),
            saveWorkLogUseCase: SaveWorkLogUseCase(repository: workLogRepo),
            parseSearchQueryUseCase: ParseSearchQueryUseCase(parser: parser, analytics: analytics),
            searchEventsUseCase: SearchEventsUseCase(
                fetchEvents: FetchCalendarEventsForPeriodUseCase(calendarService: calendarService),
                fetchDozyEvents: FetchDozyEventsForPeriodUseCase(repository: dozyRepo),
                fetchCompletions: FetchEventCompletionsForPeriodUseCase(repository: MockEventCompletionRepository())
            ),
            debounce: .seconds(60),   // 테스트는 submitNow() 로 해석을 확정한다
            now: { fixedNow }
        )
    }

    override func tearDown() {
        vm = nil
        calendarService = nil
        dozyRepo = nil
        workLogRepo = nil
        displayRepo = nil
        parser = nil
        analytics = nil
        super.tearDown()
    }

    /// receive(on: main) 로 넘어온 값을 기다린다
    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    // MARK: - 외부 일정 지연 조회

    func test_init_doesNotFetchExternalEvents() {
        XCTAssertTrue(calendarService.rangeCalls.isEmpty)
    }

    func test_whitespaceQuery_doesNotFetch() {
        vm.query = "   "
        XCTAssertTrue(calendarService.rangeCalls.isEmpty)
    }

    func test_firstQuery_fetchesOnce_tenYearsBackTwoYearsAhead() {
        vm.query = "회"
        vm.query = "회의"
        vm.query = ""
        vm.query = "운동"
        XCTAssertEqual(calendarService.rangeCalls.count, 1)
        let call = calendarService.rangeCalls[0]
        let cal = Calendar.current
        XCTAssertEqual(call.start, cal.date(byAdding: .year, value: -10, to: now))
        XCTAssertEqual(call.end, cal.date(byAdding: .year, value: 2, to: now))
    }

    func test_externalEvents_excludeDozySource() {
        calendarService.stubbedEvents = [
            makeTestEvent(title: "애플 회의", source: .apple),
            makeTestEvent(title: "도지 회의", source: .dozy)
        ]
        vm.query = "회의"
        waitUntil { !vm.externalEvents.isEmpty }
        XCTAssertEqual(vm.externalEvents.map(\.title), ["애플 회의"])
        XCTAssertEqual(vm.results(dozyEvents: [], workLogs: [], categories: []).events.map(\.title), ["애플 회의"])
    }

    // MARK: - 표시 설정

    func test_applyDisplaySettings_dozy_updatesModelAndCategoryColor() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        let category = UserCategory(name: "건강", emoji: "💪", colorHex: "#00FF00")
        vm.applyDisplaySettings(event: dozy.toCalendarEvent(), priority: 2, isPinned: true, category: "건강",
                                dozyEvents: [dozy], categories: [category])
        XCTAssertEqual(dozy.priority, 2)
        XCTAssertTrue(dozy.isPinned)
        XCTAssertEqual(dozy.category, "건강")
        XCTAssertEqual(dozy.colorHex, "#00FF00")
        XCTAssertEqual(dozyRepo.updateCallCount, 1)
        XCTAssertTrue(displayRepo.saved.isEmpty)
    }

    func test_applyDisplaySettings_external_savesSettings_fallingBackToEventCategory() {
        let ev = makeTestEvent(title: "외부", source: .google, category: "업무")
        vm.applyDisplaySettings(event: ev, priority: 1, isPinned: false, category: nil,
                                dozyEvents: [], categories: [])
        XCTAssertEqual(displayRepo.saved.count, 1)
        XCTAssertEqual(displayRepo.saved[0].eventID, ev.id)
        XCTAssertEqual(displayRepo.saved[0].category, "업무")
        XCTAssertEqual(dozyRepo.updateCallCount, 0)
    }

    // MARK: - 메모 삭제

    func test_confirmMemoDelete_dozy_removesMemoAndSaves() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        dozy.memos = ["회의 메모", "기타"]
        vm.requestMemoDelete("회의 메모", from: .dozyEvent(dozy))
        vm.confirmMemoDelete()
        XCTAssertEqual(dozy.memos, ["기타"])
        XCTAssertEqual(dozy.updatedAt, now)
        XCTAssertEqual(dozyRepo.updateCallCount, 1)
        XCTAssertNil(vm.pendingMemoDelete)
    }

    func test_confirmMemoDelete_workLog_removesMemoAndSaves() {
        let log = WorkLog(date: now)
        log.memos = ["a", "회의 메모"]
        vm.requestMemoDelete("회의 메모", from: .workLog(log))
        vm.confirmMemoDelete()
        XCTAssertEqual(log.memos, ["a"])
        XCTAssertEqual(workLogRepo.saveCallCount, 1)
        XCTAssertNil(vm.pendingMemoDelete)
    }

    func test_confirmMemoDelete_withoutPending_doesNothing() {
        vm.confirmMemoDelete()
        XCTAssertEqual(dozyRepo.updateCallCount, 0)
        XCTAssertEqual(workLogRepo.saveCallCount, 0)
    }

    // MARK: - 토스트 (#143)

    func test_saveDozy_success_showsUpdatedToast() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        vm.save(dozy)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.style, .success)
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdated.message)
    }

    func test_saveDozy_failure_showsFailureToast() {
        dozyRepo.stubbedError = .saveFailed(underlying: NSError(domain: "test", code: 1))
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        vm.save(dozy)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.style, .failure)
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdateFailed.message)
    }

    func test_confirmMemoDelete_dozy_showsNoToast() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        dozy.memos = ["회의 메모"]
        vm.requestMemoDelete("회의 메모", from: .dozyEvent(dozy))
        vm.confirmMemoDelete()
        waitUntil { dozyRepo.updateCallCount == 1 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(vm.toast)
    }

    func test_applyDisplaySettings_showsDisplaySettingsToast() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        vm.applyDisplaySettings(event: dozy.toCalendarEvent(), priority: 1, isPinned: true, category: nil,
                                dozyEvents: [dozy], categories: [])
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.displaySettingsSaved.message)

        vm.toast = nil
        let ev = makeTestEvent(title: "외부", source: .google)
        vm.applyDisplaySettings(event: ev, priority: 1, isPinned: false, category: nil,
                                dozyEvents: [], categories: [])
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.displaySettingsSaved.message)
    }

    // MARK: - 편집 후 상세 갱신

    func test_saveDozy_refreshesOpenDetailSnapshot() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        vm.selectedEvent = dozy.toCalendarEvent()
        dozy.title = "저녁 운동"   // EventEditViewModel 이 모델을 직접 고친 뒤 넘겨준다
        vm.save(dozy)
        waitUntil { vm.selectedEvent?.title == "저녁 운동" }
        XCTAssertEqual(vm.selectedEvent?.title, "저녁 운동")
        XCTAssertEqual(dozyRepo.updateCallCount, 1)
    }

    func test_saveDozy_doesNotOpenDetailForOtherEvent() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        let other = makeTestEvent(title: "다른 일정")
        vm.selectedEvent = other
        vm.save(dozy)
        waitUntil { dozyRepo.updateCallCount == 1 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(vm.selectedEvent?.id, other.id)
    }

    func test_saveCalendarEdit_refetchesExternalAndRefreshesDetail() {
        let original = makeTestEvent(title: "회의", source: .apple)
        calendarService.stubbedEvents = [original]
        vm.query = "회의"
        waitUntil { !vm.externalEvents.isEmpty }
        vm.selectedEvent = original

        let edited = CalendarEvent(
            id: original.id, calendarId: nil, title: "주간 회의",
            startDate: original.startDate, endDate: original.endDate,
            location: nil, notes: nil, isAllDay: false,
            calendarName: "테스트", calendarColorHex: "#007AFF",
            source: .apple, priority: 0, isPinned: false, category: "일반"
        )
        calendarService.stubbedEvents = [edited]
        vm.saveCalendarEdit(original, with: CalendarEventEditRequest(
            title: "주간 회의", startDate: original.startDate, endDate: original.endDate,
            isAllDay: false, location: nil, notes: nil
        ))
        waitUntil { vm.selectedEvent?.title == "주간 회의" }
        XCTAssertEqual(calendarService.rangeCalls.count, 2)
        XCTAssertEqual(vm.externalEvents.map(\.title), ["주간 회의"])
        XCTAssertEqual(vm.selectedEvent?.title, "주간 회의")
    }

    func test_refreshed_picksSameIdNearestToOriginalStart() {
        let cal = Calendar.current
        let base = makeTestEvent(title: "반복")
        func occurrence(daysFromBase d: Int) -> CalendarEvent {
            CalendarEvent(
                id: base.id, calendarId: nil, title: "반복 \(d)",
                startDate: cal.date(byAdding: .day, value: d, to: base.startDate)!,
                endDate: cal.date(byAdding: .day, value: d, to: base.endDate)!,
                location: nil, notes: nil, isAllDay: false,
                calendarName: "테스트", calendarColorHex: "#007AFF",
                source: .apple, priority: 0, isPinned: false, category: "일반"
            )
        }
        let events = [occurrence(daysFromBase: -7), occurrence(daysFromBase: 0), occurrence(daysFromBase: 7),
                      makeTestEvent(title: "무관")]
        XCTAssertEqual(SearchViewModel.refreshed(base, in: events)?.title, "반복 0")
        XCTAssertNil(SearchViewModel.refreshed(makeTestEvent(), in: events))
    }

    // MARK: - 자연어 질의 (#72)

    private var lastWeek: SearchQueryIntent.Period {
        let cal = Calendar.current
        return .init(start: cal.date(from: DateComponents(year: 2026, month: 10, day: 19))!,
                     end: cal.date(from: DateComponents(year: 2026, month: 10, day: 26))!,
                     label: "지난주")
    }

    private func meeting(_ title: String, day: Int, startHour: Int = 10, endHour: Int = 11) -> CalendarEvent {
        let cal = Calendar.current
        return CalendarEvent(
            id: UUID().uuidString, calendarId: nil, title: title,
            startDate: cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: startHour))!,
            endDate: cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: endHour))!,
            location: nil, notes: nil, isAllDay: false,
            calendarName: "테스트", calendarColorHex: "#007AFF",
            source: .apple, priority: 0, isPinned: false, category: "일반"
        )
    }

    func test_periodQuery_showsInterpretationWithAggregateAndPeriodEvents() {
        calendarService.stubbedEvents = [meeting("회의", day: 20), meeting("회의", day: 22, endHour: 12), meeting("점심", day: 21)]
        parser.stubbedIntent = SearchQueryIntent(period: lastWeek, keyword: "회의", aggregation: .totalHours)
        vm.categoryNames = ["업무"]
        vm.query = "지난주 회의 몇 시간"
        vm.submitNow()
        waitUntil { vm.interpretation?.result != nil }

        XCTAssertEqual(parser.receivedTexts, ["지난주 회의 몇 시간"])
        XCTAssertEqual(parser.receivedCategories, ["업무"])
        XCTAssertEqual(vm.interpretation?.result?.aggregate?.totalMinutes, 180)
        XCTAssertEqual(vm.results(dozyEvents: [], workLogs: [], categories: []).events.count, 2)
        XCTAssertFalse(vm.isInterpreting)
        XCTAssertEqual(analytics.trackedEvents, [.searchQuery(kind: .aggregate, engine: .rules)])
    }

    func test_keywordQuery_staysOnKeywordSearch() {
        calendarService.stubbedEvents = [meeting("회의", day: 20)]
        parser.stubbedIntent = SearchQueryIntent(keyword: "회의")
        vm.query = "회의"
        vm.submitNow()
        waitUntil { !vm.externalEvents.isEmpty && !parser.receivedTexts.isEmpty && !vm.isInterpreting }
        XCTAssertNil(vm.interpretation)
        XCTAssertEqual(vm.results(dozyEvents: [], workLogs: [], categories: []).events.map(\.title), ["회의"])
    }

    func test_submitTwice_interpretsOnce() {
        parser.stubbedIntent = SearchQueryIntent(keyword: "회의")
        vm.query = "회의"
        vm.submitNow()
        vm.submitNow()
        waitUntil { !parser.receivedTexts.isEmpty }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(parser.receivedTexts.count, 1)
    }

    func test_typingAgain_clearsInterpretation() {
        parser.stubbedIntent = SearchQueryIntent(period: lastWeek, keyword: "회의", aggregation: .count)
        vm.query = "지난주 회의 몇 번"
        vm.submitNow()
        waitUntil { vm.interpretation?.result != nil }
        vm.query = "지난주 회의 몇 번 했"
        XCTAssertNil(vm.interpretation)
    }

    func test_removePeriod_fallsBackToKeywordSearchWithInterpretedKeyword() {
        calendarService.stubbedEvents = [meeting("회의", day: 20), meeting("점심", day: 21)]
        parser.stubbedIntent = SearchQueryIntent(period: lastWeek, keyword: "회의", aggregation: .count)
        vm.query = "지난주 회의 몇 번"
        vm.submitNow()
        waitUntil { vm.interpretation?.result != nil && !vm.externalEvents.isEmpty }

        vm.removePeriod()

        XCTAssertNil(vm.interpretation)
        XCTAssertEqual(vm.keywordOverride, "회의")
        XCTAssertEqual(vm.results(dozyEvents: [], workLogs: [], categories: []).events.map(\.title), ["회의"])
    }

    func test_removeCategory_rerunsWithoutHint() {
        calendarService.stubbedEvents = [meeting("헬스", day: 20)]
        parser.stubbedIntent = SearchQueryIntent(period: lastWeek, keyword: "운동", categoryHint: "운동", aggregation: .count)
        vm.query = "지난주 운동 몇 번"
        vm.submitNow()
        waitUntil { vm.interpretation?.result != nil }

        vm.removeCategory()
        waitUntil { vm.interpretation?.intent.categoryHint == nil && vm.interpretation?.result != nil && !vm.isInterpreting }

        XCTAssertNil(vm.interpretation?.intent.categoryHint)
        XCTAssertEqual(vm.interpretation?.intent.period, lastWeek)
    }

    // MARK: - 백그라운드

    func test_clearModalState_resetsAllSheets() {
        let dozy = DozyEvent(title: "운동", startDate: now, endDate: now)
        vm.selectedEvent = dozy.toCalendarEvent()
        vm.dozyEventToEdit = dozy
        vm.calendarEventToEdit = makeTestEvent()
        vm.requestMemoDelete("m", from: .dozyEvent(dozy))
        vm.clearModalState()
        XCTAssertNil(vm.selectedEvent)
        XCTAssertNil(vm.dozyEventToEdit)
        XCTAssertNil(vm.calendarEventToEdit)
        XCTAssertNil(vm.pendingMemoDelete)
    }
}
