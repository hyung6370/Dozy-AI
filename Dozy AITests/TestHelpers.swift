//
//  TestHelpers.swift
//  Dozy AITests
//

import XCTest
import Combine
@testable import Dozy_AI

// MARK: - Combine Test Helper

extension XCTestCase {
    /// Publisher가 방출하는 첫 번째 값을 기다렸다가 반환합니다. 실패 시 에러를 throw합니다.
    @discardableResult
    func awaitPublisher<T, E: Error>(
        _ publisher: AnyPublisher<T, E>,
        timeout: TimeInterval = 2.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        var result: Result<T, E>?
        let expectation = self.expectation(description: "Publisher completion")
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion { result = .failure(error) }
                expectation.fulfill()
            },
            receiveValue: { result = .success($0) }
        )
        defer { cancellable.cancel() }
        wait(for: [expectation], timeout: timeout)
        guard let result else {
            XCTFail("Publisher가 값을 방출하지 않았습니다", file: file, line: line)
            throw XCTestError(.failureWhileWaiting)
        }
        return try result.get()
    }
}

// MARK: - Test Data Factories

func makeTestEvent(
    title: String = "테스트 이벤트",
    startHour: Int = 9, endHour: Int = 10,
    isAllDay: Bool = false,
    location: String? = nil,
    source: CalendarSource = .apple
) -> CalendarEvent {
    var c = DateComponents()
    c.year = 2026; c.month = 4; c.day = 11
    let start = Calendar.current.date(from: { c.hour = startHour; return c }())!
    let end   = Calendar.current.date(from: { c.hour = endHour;   return c }())!
    return CalendarEvent(
        id: UUID().uuidString, calendarId: nil, title: title,
        startDate: start, endDate: end,
        location: location, notes: nil, isAllDay: isAllDay,
        calendarName: "테스트", calendarColorHex: "#007AFF",
        source: source, priority: 0, isPinned: false, category: "일반"
    )
}

func makeTestTask(title: String = "테스트 할 일", priority: Int = 0) -> TaskItem {
    TaskItem(
        id: UUID().uuidString, title: title, isCompleted: true,
        completedDate: Date(), dueDate: nil,
        priority: priority, listName: "리마인더", notes: nil
    )
}

func makeTestSummary(
    summaryText: String = "오늘 수고하셨습니다",
    highlights: [String] = ["하이라이트 1", "하이라이트 2"],
    nextActions: [String] = ["다음 할 일 1"],
    category: String = "업무",
    score: Double = 0.8
) -> DailySummary {
    DailySummary(
        date: Date(), summaryText: summaryText,
        highlights: highlights, nextActions: nextActions,
        detectedCategory: category, productivityScore: score,
        totalEventMinutes: 120, completedTaskCount: 3
    )
}
