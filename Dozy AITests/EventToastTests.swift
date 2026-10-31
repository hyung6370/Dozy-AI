//
//  EventToastTests.swift
//  Dozy AITests
//
//  일정 수정 · 삭제 결과 토스트 (#143) — 캘린더 · 홈 ViewModel 이 동작마다 맞는 토스트를 띄우고,
//  실패하면 실패 토스트 + Crashlytics 비치명 기록을 남기는지 고정한다. (검색은 SearchViewModelTests)
//

import XCTest
import Combine
import SwiftData
@testable import Dozy_AI

// MARK: - Mocks

private final class StubCalendarWriteService: CalendarWriteServiceProtocol {
    var updateError: DozyError?
    var deleteError: DozyError?

    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError> {
        if let updateError { return Fail(error: updateError).eraseToAnyPublisher() }
        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func deleteEvent(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError> {
        if let deleteError { return Fail(error: deleteError).eraseToAnyPublisher() }
        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

private final class StubNotificationService: NotificationServiceProtocol {
    func requestAuthorization() -> AnyPublisher<Bool, Never> { Just(true).eraseToAnyPublisher() }
    func schedule(identifier: String, title: String, body: String, triggerDate: Date) {}
    func cancel(identifier: String) {}
}

// MARK: - 공통

@MainActor
private enum ToastTestSupport {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            WorkLog.self, UserPattern.self, DozyEvent.self,
            EventCompletion.self, NotificationRecord.self,
            EventDisplaySettings.self, UserCategory.self,
            TodayEventCache.self
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    static let failure = DozyError.saveFailed(underlying: NSError(domain: "test", code: 1))

    static func editRequest(for event: CalendarEvent) -> CalendarEventEditRequest {
        CalendarEventEditRequest(
            title: "주간 회의", startDate: event.startDate, endDate: event.endDate,
            isAllDay: false, location: nil, notes: nil
        )
    }
}

private extension XCTestCase {
    /// 메인 런루프를 돌리며 조건을 기다린다 — ViewModel 은 receive(on: main) 로 결과를 받는다.
    func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

// MARK: - DozyToast

@MainActor
final class DozyToastTests: XCTestCase {

    func test_eventToasts_haveExpectedStyles() {
        XCTAssertEqual(DozyToast.eventUpdated.style, .success)
        XCTAssertEqual(DozyToast.eventDeleted.style, .success)
        XCTAssertEqual(DozyToast.occurrenceDeleted.style, .success)
        XCTAssertEqual(DozyToast.futureOccurrencesDeleted.style, .success)
        XCTAssertEqual(DozyToast.displaySettingsSaved.style, .success)
        XCTAssertEqual(DozyToast.eventUpdateFailed.style, .failure)
        XCTAssertEqual(DozyToast.eventDeleteFailed.style, .failure)
        XCTAssertEqual(DozyToast.memoSaveFailed.style, .failure)
        XCTAssertEqual(DozyToast.memoDeleteFailed.style, .failure)
    }

    func test_sameMessage_getsNewIdentity() {
        // 같은 문구가 연달아 와도 다시 뜨고 타이머가 새로 시작돼야 한다
        XCTAssertNotEqual(DozyToast.eventDeleted, DozyToast.eventDeleted)
        XCTAssertEqual(DozyToast.eventDeleted.message, DozyToast.eventDeleted.message)
    }
}

// MARK: - CalendarViewModel

@MainActor
final class CalendarViewModelToastTests: XCTestCase {

    private var vm: CalendarViewModel!
    private var dozyRepo: MockDozyEventRepository!
    private var writeService: StubCalendarWriteService!
    private var crash: MockCrashReportingService!
    private var previousCrash: CrashReportingServiceProtocol!
    private var container: ModelContainer!
    // 지역 변수로 만들면 MainActor init 에 넘기는 순간 영역이 넘어가 두 번째 사용이 Swift 6 경계 위반이 된다.
    // 저장 프로퍼티는 테스트 클래스(MainActor) 영역이라 여러 UseCase 에 넘겨도 된다.
    private var calendarService: MockCalendarService!
    private var completions: MockEventCompletionRepository!
    private var notificationService: StubNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        container = try ToastTestSupport.makeContainer()
        dozyRepo = MockDozyEventRepository()
        writeService = StubCalendarWriteService()
        crash = MockCrashReportingService()
        previousCrash = CrashReporting.current
        CrashReporting.current = crash

        calendarService = MockCalendarService()
        completions = MockEventCompletionRepository()
        notificationService = StubNotificationService()
        vm = CalendarViewModel(
            fetchEventsUseCase: FetchCalendarEventUseCase(calendarService: calendarService),
            fetchDozyEventsUseCase: FetchDozyEventsUseCase(repository: dozyRepo),
            createEventUseCase: CreateDozyEventUseCase(repository: dozyRepo),
            updateEventUseCase: UpdateDozyEventUseCase(repository: dozyRepo),
            deleteEventUseCase: DeleteDozyEventUseCase(repository: dozyRepo),
            scheduleNotificationUseCase: ScheduleNotificationUseCase(
                service: notificationService,
                notificationRepository: NotificationRepository(modelContainer: container)
            ),
            cancelNotificationUseCase: CancelNotificationUseCase(service: notificationService),
            toggleCompletionUseCase: ToggleDozyEventCompletionUseCase(repository: dozyRepo),
            updateCalendarEventUseCase: UpdateCalendarEventUseCase(service: writeService),
            deleteCalendarEventUseCase: DeleteCalendarEventUseCase(service: writeService),
            toggleCalendarEventCompletionUseCase: ToggleCalendarEventCompletionUseCase(repository: completions),
            fetchEventCompletionsUseCase: FetchEventCompletionsUseCase(repository: completions),
            fetchDozyEventsForPeriodUseCase: FetchDozyEventsForPeriodUseCase(repository: dozyRepo),
            fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase(calendarService: calendarService),
            mirrorExternalEventUseCase: MirrorExternalEventUseCase(repository: dozyRepo),
            displaySettingsRepo: EventDisplaySettingsRepository(modelContainer: container),
            visibilityFilter: CalendarVisibilityFilter(defaults: UserDefaults(suiteName: "CalendarViewModelToastTests")!),
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        CrashReporting.current = previousCrash
        vm = nil
        dozyRepo = nil
        writeService = nil
        crash = nil
        calendarService = nil
        completions = nil
        notificationService = nil
        container = nil
        try await super.tearDown()
    }

    private func makeDozy(_ title: String = "운동") -> DozyEvent {
        DozyEvent(title: title, startDate: Date(), endDate: Date().addingTimeInterval(3600))
    }

    // 수정

    func test_saveEvent_editing_showsUpdatedToast() {
        let dozy = makeDozy()
        vm.eventToEdit = dozy
        vm.saveEvent(dozy)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdated.message)
        XCTAssertFalse(vm.showSuccessAnimation)
    }

    func test_saveEvent_creating_showsLottieNotToast() {
        let dozy = makeDozy()
        vm.eventToEdit = nil
        vm.saveEvent(dozy)
        waitUntil { vm.showSuccessAnimation }
        XCTAssertTrue(vm.showSuccessAnimation)
        XCTAssertNil(vm.toast)
    }

    func test_saveEvent_editingFails_showsFailureToastAndRecords() {
        dozyRepo.stubbedError = ToastTestSupport.failure
        let dozy = makeDozy()
        vm.eventToEdit = dozy
        vm.saveEvent(dozy)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.style, .failure)
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdateFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["calendar.event.update"])
    }

    func test_saveCalendarEvent_success_and_failure() {
        let event = makeTestEvent(title: "회의", source: .apple)
        vm.saveCalendarEvent(event, edit: ToastTestSupport.editRequest(for: event))
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdated.message)

        vm.toast = nil
        writeService.updateError = ToastTestSupport.failure
        vm.saveCalendarEvent(event, edit: ToastTestSupport.editRequest(for: event))
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdateFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["calendar.event.update_external"])
    }

    // 삭제

    func test_deleteEvent_closesDetailAndShowsDeletedToast() {
        vm.showEventDetail = true
        vm.deleteEvent(makeDozy())
        waitUntil { vm.toast != nil }
        XCTAssertFalse(vm.showEventDetail)
        XCTAssertEqual(vm.toast?.message, DozyToast.eventDeleted.message)
    }

    func test_deleteEvent_failure_keepsDetailAndShowsFailureToast() {
        dozyRepo.stubbedDeleteError = ToastTestSupport.failure
        vm.showEventDetail = true
        vm.deleteEvent(makeDozy())
        waitUntil { vm.toast != nil }
        XCTAssertTrue(vm.showEventDetail)
        XCTAssertEqual(vm.toast?.message, DozyToast.eventDeleteFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["calendar.event.delete"])
    }

    func test_deleteOccurrences_showRecurringToasts() {
        let dozy = makeDozy()
        dozy.recurrenceRule = "daily"
        vm.deleteThisOccurrence(dozy, date: Date())
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.occurrenceDeleted.message)

        vm.toast = nil
        vm.deleteFutureOccurrences(dozy, from: Date().addingTimeInterval(86_400 * 3))
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.futureOccurrencesDeleted.message)
    }

    func test_deleteCalendarEvent_success_and_failure() {
        let event = makeTestEvent(title: "회의", source: .google)
        vm.deleteCalendarEvent(event)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventDeleted.message)

        vm.toast = nil
        writeService.deleteError = ToastTestSupport.failure
        vm.deleteCalendarEvent(event)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventDeleteFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["calendar.event.delete_external"])
    }

    // 메모 (#144)

    func test_saveMemos_failure_showsMemoFailureToast() {
        dozyRepo.stubbedError = ToastTestSupport.failure
        vm.saveMemos(for: makeDozy())
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.memoSaveFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["calendar.event.memo"])
    }

    func test_saveMemos_success_showsNoToast() {
        vm.saveMemos(for: makeDozy())
        waitUntil { dozyRepo.updateCallCount == 1 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(vm.toast)
    }

    // 표시 설정

    func test_updateDisplaySettings_dozyAndExternal_showSavedToast() {
        let dozy = makeDozy()
        vm.dozyEventsByID[dozy.id] = dozy
        vm.updateDisplaySettings(for: dozy.toCalendarEvent(), priority: 2, isPinned: true)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.displaySettingsSaved.message)

        vm.toast = nil
        let external = makeTestEvent(title: "외부", source: .apple)
        vm.updateDisplaySettings(for: external, priority: 1, isPinned: false)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.displaySettingsSaved.message)
    }
}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModelToastTests: XCTestCase {

    private var vm: HomeViewModel!
    private var workLogRepo: MockWorkLogRepository!
    private var dozyRepo: MockDozyEventRepository!
    private var writeService: StubCalendarWriteService!
    private var crash: MockCrashReportingService!
    private var previousCrash: CrashReportingServiceProtocol!
    private var container: ModelContainer!
    // CalendarViewModelToastTests 와 같은 이유로 저장 프로퍼티.
    private var calendarService: MockCalendarService!
    private var completions: MockEventCompletionRepository!

    override func setUp() async throws {
        try await super.setUp()
        container = try ToastTestSupport.makeContainer()
        dozyRepo = MockDozyEventRepository()
        writeService = StubCalendarWriteService()
        crash = MockCrashReportingService()
        previousCrash = CrashReporting.current
        CrashReporting.current = crash

        calendarService = MockCalendarService()
        completions = MockEventCompletionRepository()
        workLogRepo = MockWorkLogRepository()
        vm = HomeViewModel(
            fetchTodayDataUseCase: FetchTodayDataUseCase(calendarService: calendarService, reminderService: MockReminderService()),
            saveWorkLogUseCase: SaveWorkLogUseCase(repository: workLogRepo),
            generateDailySummaryUseCase: GenerateDailySummaryUseCase(aiService: MockAIService(), repository: workLogRepo),
            fetchRecentLogsUseCase: FetchRecentLogsUseCase(repository: workLogRepo),
            calendarSourceManager: CalendarSourceManager(),
            googleSignInService: GoogleSignInService(),
            fetchCalendarEventUseCase: FetchCalendarEventUseCase(calendarService: calendarService),
            fetchDozyEventsUseCase: FetchDozyEventsUseCase(repository: dozyRepo),
            fetchEventCompletionsUseCase: FetchEventCompletionsUseCase(repository: completions),
            fetchCalendarEventsForPeriodUseCase: FetchCalendarEventsForPeriodUseCase(calendarService: calendarService),
            deleteDozyEventUseCase: DeleteDozyEventUseCase(repository: dozyRepo),
            deleteCalendarEventUseCase: DeleteCalendarEventUseCase(service: writeService),
            createDozyEventUseCase: CreateDozyEventUseCase(repository: dozyRepo),
            updateDozyEventUseCase: UpdateDozyEventUseCase(repository: dozyRepo),
            updateCalendarEventUseCase: UpdateCalendarEventUseCase(service: writeService),
            displaySettingsRepo: EventDisplaySettingsRepository(modelContainer: container),
            notificationRepository: NotificationRepository(modelContainer: container),
            toggleEventCompletionUseCase: ToggleEventCompletionUseCase(
                toggleDozy: ToggleDozyEventCompletionUseCase(repository: dozyRepo),
                toggleCalendar: ToggleCalendarEventCompletionUseCase(repository: completions)
            ),
            modelContainer: container
        )
    }

    override func tearDown() async throws {
        CrashReporting.current = previousCrash
        vm = nil
        workLogRepo = nil
        dozyRepo = nil
        writeService = nil
        crash = nil
        calendarService = nil
        completions = nil
        container = nil
        try await super.tearDown()
    }

    private func makeDozy(_ title: String = "운동") -> DozyEvent {
        DozyEvent(title: title, startDate: Date(), endDate: Date().addingTimeInterval(3600))
    }

    // 수정

    func test_saveDozyEvent_existing_showsUpdatedToast() {
        let dozy = makeDozy()
        vm.dozyEventsByID[dozy.id] = dozy
        vm.saveDozyEvent(dozy)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdated.message)
        XCTAssertFalse(vm.showSuccessAnimation)
    }

    func test_saveDozyEvent_new_showsLottieNotToast() {
        vm.saveDozyEvent(makeDozy())
        waitUntil { vm.showSuccessAnimation }
        XCTAssertTrue(vm.showSuccessAnimation)
        XCTAssertNil(vm.toast)
    }

    func test_saveDozyEvent_existingFails_showsFailureToastAndRecords() {
        dozyRepo.stubbedError = ToastTestSupport.failure
        let dozy = makeDozy()
        vm.dozyEventsByID[dozy.id] = dozy
        vm.saveDozyEvent(dozy)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdateFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["home.event.update"])
    }

    func test_saveCalendarEvent_success_and_failure() {
        let event = makeTestEvent(title: "회의", source: .apple)
        vm.saveCalendarEvent(event, edit: ToastTestSupport.editRequest(for: event))
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdated.message)

        vm.toast = nil
        writeService.updateError = ToastTestSupport.failure
        vm.saveCalendarEvent(event, edit: ToastTestSupport.editRequest(for: event))
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventUpdateFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["home.event.update_external"])
    }

    // 삭제

    func test_deleteDozyEvent_success_and_failure() {
        vm.deleteDozyEvent(makeDozy())
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventDeleted.message)

        vm.toast = nil
        dozyRepo.stubbedDeleteError = ToastTestSupport.failure
        vm.deleteDozyEvent(makeDozy())
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventDeleteFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["home.event.delete"])
    }

    func test_deleteOccurrences_showRecurringToasts() {
        let dozy = makeDozy()
        dozy.recurrenceRule = "daily"
        vm.deleteThisOccurrence(dozy, date: Date())
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.occurrenceDeleted.message)

        vm.toast = nil
        vm.deleteFutureOccurrences(dozy, from: Date().addingTimeInterval(86_400 * 3))
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.futureOccurrencesDeleted.message)
    }

    func test_deleteCalendarEvent_failure_recordsExternalContext() {
        writeService.deleteError = ToastTestSupport.failure
        vm.deleteCalendarEvent(makeTestEvent(title: "회의", source: .google))
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.eventDeleteFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["home.event.delete_external"])
    }

    // 메모 (#144)

    func test_updateMemo_failure_showsMemoSaveFailedToast() {
        let log = WorkLog(date: Date())
        log.addMemo("회의 정리")
        vm.todayLog = log
        workLogRepo.stubbedSaveError = ToastTestSupport.failure
        vm.updateMemo(at: 0, text: "회의 정리 끝")
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.memoSaveFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["home.memo.update"])
    }

    func test_deleteMemo_failure_showsMemoDeleteFailedToast() {
        let log = WorkLog(date: Date())
        log.addMemo("회의 정리")
        vm.todayLog = log
        workLogRepo.stubbedSaveError = ToastTestSupport.failure
        vm.deleteMemo(at: 0)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.memoDeleteFailed.message)
        XCTAssertEqual(crash.recorded.map(\.context), ["home.memo.delete"])
    }

    func test_deleteMemo_success_showsNoToast() {
        let log = WorkLog(date: Date())
        log.addMemo("회의 정리")
        vm.todayLog = log
        vm.deleteMemo(at: 0)
        waitUntil { workLogRepo.saveCallCount > 0 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(vm.toast)
    }

    // 표시 설정

    func test_updateDisplaySettings_external_showsSavedToast() {
        vm.updateDisplaySettings(for: makeTestEvent(title: "외부", source: .apple), priority: 1, isPinned: true, category: nil)
        waitUntil { vm.toast != nil }
        XCTAssertEqual(vm.toast?.message, DozyToast.displaySettingsSaved.message)
    }
}
