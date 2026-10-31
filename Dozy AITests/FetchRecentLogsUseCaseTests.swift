//
//  FetchRecentLogsUseCaseTests.swift
//  Dozy AITests
//
//  Created by Hyungjun KIM on 8/4/26.
//

import XCTest
import Combine
@testable import Dozy_AI

@MainActor
final class FetchRecentLogsUseCaseTests: XCTestCase {
    
    private var repository: MockWorkLogRepository!
    private var useCase: FetchRecentLogsUseCase!
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() async throws {
        try await super.setUp()
        repository = MockWorkLogRepository()
        useCase = FetchRecentLogsUseCase(repository: repository)
    }
    
    override func tearDown() async throws { cancellables.removeAll(); try await super.tearDown() }
    
    // MARK: - 반환값 전달
    func test_execute_returnsLogsFromRepository() throws {
        repository.stubbedRecentLogs = [WorkLog(date: Date()), WorkLog(date: Date())]
        let logs = try awaitPublisher(useCase.execute())
        XCTAssertEqual(logs.count, 2)
    }
    
    func test_execute_emptyRepository_returnsEmptyArray() throws {
        repository.stubbedRecentLogs = []
        let logs = try awaitPublisher(useCase.execute())
        XCTAssertTrue(logs.isEmpty)
    }
    
    // MARK: - days 인자 전달
    func test_execute_defaultDays_passesSeven() throws {
        _ = try awaitPublisher(useCase.execute())
        XCTAssertEqual(repository.receivedDays, 7)
    }
    
    func test_execute_explicitDays_passesThrough() throws {
        _ = try awaitPublisher(useCase.execute(days: 30))
        XCTAssertEqual(repository.receivedDays, 30)
    }
    
    func test_execute_callsRepositoryExactlyOnce() throws {
        _ = try awaitPublisher(useCase.execute())
        XCTAssertEqual(repository.fetchRecentCallCount, 1)
    }
    
    // MARK: - 실패 경로
    func test_execute_whenRepositoryFails_propagatesError() {
        repository.stubbedFetchError = .dataNotFound
        let expectation = self.expectation(description: "에러 수신")
        useCase.execute()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion,
                       case .dataNotFound = error { expectation.fulfill() }
                }, receiveValue: { _ in XCTFail("값이 반환되면 안됩니다") }
            )
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }
}
