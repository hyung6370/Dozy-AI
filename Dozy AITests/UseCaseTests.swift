//
//  UseCaseTests.swift
//  Dozy AITests
//

import XCTest
import Combine
@testable import Dozy_AI

// MARK: - FetchTodayDataUseCase Tests

final class FetchTodayDataUseCaseTests: XCTestCase {

    private var calendarService: MockCalendarService!
    private var reminderService: MockReminderService!
    private var useCase: FetchTodayDataUseCase!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        calendarService = MockCalendarService()
        reminderService = MockReminderService()
        useCase = FetchTodayDataUseCase(calendarService: calendarService,
                                        reminderService: reminderService)
    }

    override func tearDown() { cancellables.removeAll(); super.tearDown() }

    func test_execute_returnsEventsAndTasks() throws {
        calendarService.stubbedEvents    = [makeTestEvent(title: "팀 미팅")]
        reminderService.stubbedCompleted = [makeTestTask(title: "PR 리뷰")]
        reminderService.stubbedPending   = [makeTestTask(title: "다음 작업")]

        let result = try awaitPublisher(useCase.execute())

        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events[0].title, "팀 미팅")
        XCTAssertEqual(result.completedTasks.count, 1)
        XCTAssertEqual(result.completedTasks[0].title, "PR 리뷰")
        XCTAssertEqual(result.pendingTasks.count, 1)
    }

    func test_execute_emptyData_returnsEmptyCollections() throws {
        let result = try awaitPublisher(useCase.execute())
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertTrue(result.completedTasks.isEmpty)
        XCTAssertTrue(result.pendingTasks.isEmpty)
    }

    func test_execute_multipleEvents_returnsAll() throws {
        calendarService.stubbedEvents = [
            makeTestEvent(title: "미팅 A"),
            makeTestEvent(title: "미팅 B"),
            makeTestEvent(title: "미팅 C")
        ]
        let result = try awaitPublisher(useCase.execute())
        XCTAssertEqual(result.events.count, 3)
    }

    func test_execute_whenCalendarFails_propagatesError() {
        calendarService.stubbedError = .calendarAccessDenied
        let expectation = self.expectation(description: "에러 수신")
        useCase.execute()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion,
                       case .calendarAccessDenied = error { expectation.fulfill() }
                },
                receiveValue: { _ in XCTFail("값이 반환되면 안됩니다") }
            )
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }

    func test_execute_whenReminderFails_propagatesError() {
        reminderService.stubbedError = .reminderAccessDenied
        let expectation = self.expectation(description: "에러 수신")
        useCase.execute()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion,
                       case .reminderAccessDenied = error { expectation.fulfill() }
                },
                receiveValue: { _ in XCTFail("값이 반환되면 안됩니다") }
            )
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - ToggleCalendarEventCompletionUseCase Tests

final class ToggleCalendarEventCompletionUseCaseTests: XCTestCase {

    private var repository: MockEventCompletionRepository!
    private var useCase: ToggleCalendarEventCompletionUseCase!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        repository = MockEventCompletionRepository()
        useCase = ToggleCalendarEventCompletionUseCase(repository: repository)
    }

    override func tearDown() { cancellables.removeAll(); super.tearDown() }

    func test_execute_passesCorrectEventIDToRepository() throws {
        let eventID = "test-event-123"
        _ = try awaitPublisher(useCase.execute(eventID: eventID, eventDate: Date()))
        XCTAssertEqual(repository.toggleCalledWith?.eventID, eventID)
    }

    func test_execute_passesCorrectDateToRepository() throws {
        let date = Date()
        _ = try awaitPublisher(useCase.execute(eventID: "id", eventDate: date))
        let calledDate = try XCTUnwrap(repository.toggleCalledWith?.eventDate)
        XCTAssertEqual(calledDate.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_execute_repositoryReturnsTrue_returnsTrue() throws {
        repository.stubbedToggleResult = true
        let result = try awaitPublisher(useCase.execute(eventID: "id", eventDate: Date()))
        XCTAssertTrue(result)
    }

    func test_execute_repositoryReturnsFalse_returnsFalse() throws {
        repository.stubbedToggleResult = false
        let result = try awaitPublisher(useCase.execute(eventID: "id", eventDate: Date()))
        XCTAssertFalse(result)
    }

    func test_execute_whenRepositoryFails_propagatesError() {
        repository.stubbedError = .dataNotFound
        let expectation = self.expectation(description: "에러 수신")
        useCase.execute(eventID: "id", eventDate: Date())
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion,
                       case .dataNotFound = error { expectation.fulfill() }
                },
                receiveValue: { _ in XCTFail("값이 반환되면 안됩니다") }
            )
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - ToggleDozyEventCompletionUseCase Tests

final class ToggleDozyEventCompletionUseCaseTests: XCTestCase {

    private var repository: MockDozyEventRepository!
    private var useCase: ToggleDozyEventCompletionUseCase!
    private var cancellables = Set<AnyCancellable>()

    private let baseDate: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 11
        return Calendar.current.date(from: c)!
    }()

    override func setUp() {
        super.setUp()
        repository = MockDozyEventRepository()
        useCase = ToggleDozyEventCompletionUseCase(repository: repository)
    }

    override func tearDown() { cancellables.removeAll(); super.tearDown() }

    func test_execute_togglesFalseToTrue() throws {
        let event = DozyEvent(title: "이벤트", startDate: baseDate, endDate: baseDate)
        event.isCompleted = false
        _ = try awaitPublisher(useCase.execute(event))
        XCTAssertTrue(event.isCompleted)
    }

    func test_execute_togglesTrueToFalse() throws {
        let event = DozyEvent(title: "이벤트", startDate: baseDate, endDate: baseDate)
        event.isCompleted = true
        _ = try awaitPublisher(useCase.execute(event))
        XCTAssertFalse(event.isCompleted)
    }

    func test_execute_callsRepositoryUpdateOnce() throws {
        let event = DozyEvent(title: "이벤트", startDate: baseDate, endDate: baseDate)
        _ = try awaitPublisher(useCase.execute(event))
        XCTAssertEqual(repository.updateCallCount, 1)
    }

    func test_execute_passesCorrectEventToRepository() throws {
        let event = DozyEvent(title: "중요 이벤트", startDate: baseDate, endDate: baseDate)
        _ = try awaitPublisher(useCase.execute(event))
        XCTAssertEqual(repository.lastUpdatedEvent?.title, "중요 이벤트")
    }

    func test_execute_whenRepositoryFails_propagatesError() {
        repository.stubbedError = .dataNotFound
        let event = DozyEvent(title: "이벤트", startDate: baseDate, endDate: baseDate)
        let expectation = self.expectation(description: "에러 수신")
        useCase.execute(event)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion,
                       case .dataNotFound = error { expectation.fulfill() }
                },
                receiveValue: { _ in XCTFail("값이 반환되면 안됩니다") }
            )
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - GenerateDailySummaryUseCase Tests

final class GenerateDailySummaryUseCaseTests: XCTestCase {

    private var aiService: MockAIService!
    private var repository: MockWorkLogRepository!
    private var useCase: GenerateDailySummaryUseCase!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        aiService  = MockAIService()
        repository = MockWorkLogRepository()
        useCase    = GenerateDailySummaryUseCase(aiService: aiService, repository: repository)
    }

    override func tearDown() { cancellables.removeAll(); super.tearDown() }

    func test_execute_returnsSummaryFromAI() throws {
        aiService.stubbedSummary = makeTestSummary(summaryText: "Dozy가 생성한 요약")
        repository.stubbedLog = nil

        let result = try awaitPublisher(
            useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [])
        )
        XCTAssertEqual(result.summaryText, "Dozy가 생성한 요약")
    }

    func test_execute_whenLogExists_savesToRepository() throws {
        aiService.stubbedSummary = makeTestSummary()
        repository.stubbedLog = WorkLog(date: Date())

        _ = try awaitPublisher(
            useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [])
        )
        XCTAssertEqual(repository.saveCallCount, 1)
    }

    func test_execute_whenLogExists_appliesSummaryToLog() throws {
        let summary = makeTestSummary(summaryText: "요약 텍스트", score: 0.9)
        aiService.stubbedSummary = summary
        let log = WorkLog(date: Date())
        repository.stubbedLog = log

        _ = try awaitPublisher(
            useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [])
        )
        XCTAssertEqual(log.aiSummary, "요약 텍스트")
        XCTAssertEqual(log.productivityScore, 0.9)
    }

    func test_execute_whenNoLog_doesNotSave() throws {
        aiService.stubbedSummary = makeTestSummary()
        repository.stubbedLog = nil

        _ = try awaitPublisher(
            useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [])
        )
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func test_execute_whenAIFails_propagatesError() {
        aiService.stubbedError = DozyError.aiSummarizationFailed
        let expectation = self.expectation(description: "에러 수신")
        useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [])
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion,
                       case .aiSummarizationFailed = error { expectation.fulfill() }
                },
                receiveValue: { _ in XCTFail("값이 반환되면 안됩니다") }
            )
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 3.0)
    }
}

// MARK: - ToggleEventCompletionUseCase Tests (홈·캘린더 공용 토글)

final class ToggleEventCompletionUseCaseTests: XCTestCase {

    private var dozyRepository: MockDozyEventRepository!
    private var completionRepository: MockEventCompletionRepository!
    private var useCase: ToggleEventCompletionUseCase!
    private var cancellables = Set<AnyCancellable>()

    private let baseDate: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 11; c.hour = 9
        return Calendar.current.date(from: c)!
    }()

    override func setUp() {
        super.setUp()
        dozyRepository = MockDozyEventRepository()
        completionRepository = MockEventCompletionRepository()
        useCase = ToggleEventCompletionUseCase(
            toggleDozy: ToggleDozyEventCompletionUseCase(repository: dozyRepository),
            toggleCalendar: ToggleCalendarEventCompletionUseCase(repository: completionRepository)
        )
    }

    override func tearDown() { cancellables.removeAll(); super.tearDown() }

    // MARK: target 규칙

    func test_target_dozyNonRecurring_togglesDozyEvent() {
        let dozy = DozyEvent(title: "도지", startDate: baseDate, endDate: baseDate)
        let event = makeTestEvent(source: .dozy)
        guard case .dozyEvent(let picked)? = ToggleEventCompletionUseCase.target(for: event, dozyEvent: dozy, on: Date()) else {
            return XCTFail("Dozy 비반복은 .dozyEvent 여야 합니다")
        }
        XCTAssertTrue(picked === dozy)
    }

    func test_target_dozyRecurring_usesCompletionKeyedByStartDate() {
        let dozy = DozyEvent(title: "반복", startDate: baseDate, endDate: baseDate)
        dozy.recurrenceRule = "daily"
        let event = makeTestEvent(startHour: 9, endHour: 10, source: .dozy)
        guard case .completion(let id, let date)? = ToggleEventCompletionUseCase.target(for: event, dozyEvent: dozy, on: Date()) else {
            return XCTFail("반복 Dozy 는 .completion 이어야 합니다")
        }
        XCTAssertEqual(id, event.id)
        XCTAssertEqual(date, event.startDate)
    }

    func test_target_externalCalendar_usesCompletionKeyedByGivenDate() {
        let event = makeTestEvent(source: .google)
        let reference = baseDate.addingTimeInterval(86_400)
        guard case .completion(let id, let date)? = ToggleEventCompletionUseCase.target(for: event, dozyEvent: nil, on: reference) else {
            return XCTFail("외부 캘린더는 .completion 이어야 합니다")
        }
        XCTAssertEqual(id, event.id)
        XCTAssertEqual(date, reference)
    }

    func test_target_dozyWithoutSourceEvent_isNil() {
        let event = makeTestEvent(source: .dozy)
        XCTAssertNil(ToggleEventCompletionUseCase.target(for: event, dozyEvent: nil, on: Date()))
    }

    // MARK: execute

    func test_execute_dozyEvent_returnsNewStateAndUpdatesRepository() throws {
        let dozy = DozyEvent(title: "도지", startDate: baseDate, endDate: baseDate)
        dozy.isCompleted = false
        let result = try awaitPublisher(useCase.execute(.dozyEvent(dozy)))
        XCTAssertTrue(result)
        XCTAssertTrue(dozy.isCompleted)
        XCTAssertEqual(dozyRepository.updateCallCount, 1)
        XCTAssertNil(completionRepository.toggleCalledWith)
    }

    func test_execute_completion_delegatesToCompletionRepository() throws {
        completionRepository.stubbedToggleResult = false
        let result = try awaitPublisher(useCase.execute(.completion(eventID: "ev-1", eventDate: baseDate)))
        XCTAssertFalse(result)
        XCTAssertEqual(completionRepository.toggleCalledWith?.eventID, "ev-1")
        XCTAssertEqual(completionRepository.toggleCalledWith?.eventDate, baseDate)
        XCTAssertEqual(dozyRepository.updateCallCount, 0)
    }

    func test_execute_event_withoutTarget_failsWithDataNotFound() {
        let event = makeTestEvent(source: .dozy)
        let expectation = self.expectation(description: "에러 수신")
        useCase.execute(event, dozyEvent: nil, on: Date())
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion, case .dataNotFound = error { expectation.fulfill() }
                },
                receiveValue: { _ in XCTFail("값이 반환되면 안됩니다") }
            )
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - SaveWorkLogUseCase Tests (#137)

/// 홈 메모가 일정 로딩 결과(todayLog)에 묶이지 않는지 — 오늘 WorkLog 가 없어도 메모가 저장되고,
/// 저장 실패 시 붙였던 메모가 되돌려지는지 고정한다.
final class SaveWorkLogUseCaseTests: XCTestCase {

    private var repository: MockWorkLogRepository!
    private var useCase: SaveWorkLogUseCase!

    override func setUp() {
        super.setUp()
        repository = MockWorkLogRepository()
        useCase = SaveWorkLogUseCase(repository: repository)
    }

    func test_addMemo_withoutTodayLog_createsLogAndSaves() throws {
        let log = try awaitPublisher(useCase.addMemo("회의 정리"))

        XCTAssertEqual(log.memos, ["회의 정리"])
        XCTAssertEqual(repository.createdLogCount, 1)
        XCTAssertEqual(repository.saveCallCount, 1)
    }

    func test_addMemo_withExistingLog_appendsToSameLog() throws {
        let existing = WorkLog(date: Date())
        existing.addMemo("첫 메모")
        repository.stubbedLog = existing

        let log = try awaitPublisher(useCase.addMemo("두 번째"))

        XCTAssertTrue(log === existing)
        XCTAssertEqual(log.memos, ["첫 메모", "두 번째"])
        XCTAssertEqual(repository.createdLogCount, 0)
    }

    func test_addMemo_whenSaveFails_rollsBackMemoAndFails() {
        let existing = WorkLog(date: Date())
        existing.addMemo("첫 메모")
        repository.stubbedLog = existing
        repository.stubbedSaveError = .saveFailed(underlying: NSError(domain: "test", code: 1))

        XCTAssertThrowsError(try awaitPublisher(useCase.addMemo("저장 안 될 메모")))
        XCTAssertEqual(existing.memos, ["첫 메모"])
    }

    func test_addMemo_retryAfterFailure_addsOnce() throws {
        let existing = WorkLog(date: Date())
        repository.stubbedLog = existing
        repository.stubbedSaveError = .saveFailed(underlying: NSError(domain: "test", code: 1))
        XCTAssertThrowsError(try awaitPublisher(useCase.addMemo("다시 보낼 메모")))

        repository.stubbedSaveError = nil
        let log = try awaitPublisher(useCase.addMemo("다시 보낼 메모"))

        XCTAssertEqual(log.memos, ["다시 보낼 메모"])
    }

    func test_addMemo_whenFetchFails_propagatesError() {
        repository.stubbedFetchError = .saveFailed(underlying: NSError(domain: "test", code: 2))

        XCTAssertThrowsError(try awaitPublisher(useCase.addMemo("메모")))
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func test_todayLog_withoutLog_createsOnce() throws {
        let first = try awaitPublisher(useCase.todayLog())
        let second = try awaitPublisher(useCase.todayLog())

        XCTAssertTrue(first === second)
        XCTAssertEqual(repository.createdLogCount, 1)
    }

    func test_execute_withMemoAddedFirst_keepsMemoInSameLog() throws {
        // 일정 로딩보다 메모가 먼저 저장된 경우 — 이후 일정 로딩이 새 WorkLog 를 만들어 메모를 가리면 안 된다.
        _ = try awaitPublisher(useCase.addMemo("먼저 쓴 메모"))

        let log = try awaitPublisher(useCase.execute(events: [makeTestEvent(title: "팀 미팅")], tasks: []))

        XCTAssertEqual(log.memos, ["먼저 쓴 메모"])
        XCTAssertEqual(repository.createdLogCount, 1)
    }
}
