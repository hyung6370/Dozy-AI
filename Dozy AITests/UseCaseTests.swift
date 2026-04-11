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
        aiService.stubbedSummary = makeTestSummary(summaryText: "AI가 생성한 요약")
        repository.stubbedLog = nil

        let result = try awaitPublisher(
            useCase.execute(events: [], completedTasks: [], pendingTasks: [], memos: [])
        )
        XCTAssertEqual(result.summaryText, "AI가 생성한 요약")
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
