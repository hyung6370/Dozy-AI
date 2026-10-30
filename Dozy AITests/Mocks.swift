//
//  Mocks.swift
//  Dozy AITests
//

import Foundation
import Combine
@testable import Dozy_AI

// MARK: - MockCalendarService

final class MockCalendarService: CalendarServiceProtocol {
    var stubbedEvents: [CalendarEvent] = []
    var stubbedError: DozyError? = nil
    private(set) var fetchCallCount = 0

    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchCallCount += 1
        if let error = stubbedError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(stubbedEvents).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        Just(true).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

// MARK: - MockReminderService

final class MockReminderService: ReminderServiceProtocol {
    var stubbedCompleted: [TaskItem] = []
    var stubbedPending: [TaskItem] = []
    var stubbedError: DozyError? = nil

    func fetchCompletedReminders(for date: Date) -> AnyPublisher<[TaskItem], DozyError> {
        if let error = stubbedError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(stubbedCompleted).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func fetchPendingReminders() -> AnyPublisher<[TaskItem], DozyError> {
        if let error = stubbedError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(stubbedPending).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        Just(true).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

// MARK: - MockEventCompletionRepository

final class MockEventCompletionRepository: EventCompletionRepositoryProtocol {
    var stubbedToggleResult: Bool = true
    var stubbedError: DozyError? = nil
    private(set) var toggleCalledWith: (eventID: String, eventDate: Date)?

    func fetchCompletions(for eventIDs: [String], on date: Date) -> AnyPublisher<[String: Bool], DozyError> {
        Just([:]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    /// 기간 조회 결과 (#72 SearchEventsUseCase)
    var stubbedPeriodCompletions: [EventCompletion] = []

    func fetchCompletions(from start: Date, to end: Date) -> AnyPublisher<[EventCompletion], DozyError> {
        Just(stubbedPeriodCompletions).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func toggle(eventID: String, eventDate: Date) -> AnyPublisher<Bool, DozyError> {
        toggleCalledWith = (eventID: eventID, eventDate: eventDate)
        if let error = stubbedError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(stubbedToggleResult).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

// MARK: - MockDozyEventRepository

final class MockDozyEventRepository: DozyEventRepositoryProtocol {
    var stubbedError: DozyError? = nil
    /// save 실패 시나리오용 (#90 — 실패하면 event_created 를 보내지 않아야 한다).
    var stubbedSaveError: DozyError? = nil
    private(set) var updateCallCount = 0
    private(set) var lastUpdatedEvent: DozyEvent? = nil

    /// 기간 조회 결과 (#72 SearchEventsUseCase)
    var stubbedPeriodEvents: [DozyEvent] = []

    func fetchEvents(from: Date, to: Date) -> AnyPublisher<[DozyEvent], DozyError> {
        Just(stubbedPeriodEvents).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func fetchAllRecurring() -> AnyPublisher<[DozyEvent], DozyError> {
        Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func save(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        if let error = stubbedSaveError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func update(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        updateCallCount += 1
        lastUpdatedEvent = event
        if let error = stubbedError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    /// delete 실패 시나리오용 (#143 — 삭제 실패 토스트)
    var stubbedDeleteError: DozyError? = nil
    private(set) var deleteCallCount = 0

    func delete(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        deleteCallCount += 1
        if let error = stubbedDeleteError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func mirrorExternalEvent(
        _ origin: CalendarEvent,
        to sharedCalendarID: String
    ) -> AnyPublisher<DozyEvent, DozyError> {
        let event = DozyEvent(
            title: origin.title,
            startDate: origin.startDate,
            endDate: origin.endDate,
            sharedCalendarID: sharedCalendarID,
            externalSource: origin.source.rawValue,
            externalEventID: origin.id
        )
        return Just(event).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func fetchMyExternalMirrors() -> AnyPublisher<[DozyEvent], DozyError> {
        Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func applyExternalMirrorReconcile(
        updates: [ExternalMirrorUpdate],
        deletedIDs: [String]
    ) -> AnyPublisher<Void, DozyError> {
        Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func deleteExternalMirrors(ids: [String]) -> AnyPublisher<Void, DozyError> {
        Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

// MARK: - MockAIService

final class MockAIService: AIServiceProtocol {
    var stubbedSummary: DailySummary?
    var stubbedError: Error? = nil
    var stubbedEngineStatus: AIEngineStatus = .unavailable
    var engineStatus: AIEngineStatus { stubbedEngineStatus }

    func generateDailySummary(
        events: [CalendarEvent], completedTasks: [TaskItem],
        pendingTasks: [TaskItem], memos: [String], completedEventCount: Int
    ) async throws -> DailySummary {
        if let error = stubbedError { throw error }
        return stubbedSummary!
    }

    func generateQuickSummary(
        events: [CalendarEvent], completedTasks: [TaskItem]
    ) async throws -> String {
        if let error = stubbedError { throw error }
        return "빠른 요약"
    }
}

// MARK: - MockWorkLogRepository

final class MockWorkLogRepository: WorkLogRepositoryProtocol {
    var stubbedLog: WorkLog? = nil
    var stubbedRecentLogs: [WorkLog] = []
    var stubbedFetchError: DozyError? = nil
    var stubbedSaveError: DozyError? = nil
    private(set) var saveCallCount = 0
    private(set) var receivedDays: Int?
    private(set) var fetchRecentCallCount = 0

    func fetchLog(for date: Date) -> AnyPublisher<WorkLog?, DozyError> {
        if let error = stubbedFetchError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(stubbedLog).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func fetchRecentLogs(days: Int) -> AnyPublisher<[WorkLog], DozyError> {
        receivedDays = days
        fetchRecentCallCount += 1
        if let error = stubbedFetchError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(stubbedRecentLogs).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    /// 오늘 WorkLog 가 없으면 새로 만들어 `stubbedLog` 로 기억한다 — 실제 저장소처럼 두 번째 호출은 같은 객체.
    private(set) var fetchOrCreateCallCount = 0
    private(set) var createdLogCount = 0

    func fetchOrCreateLog(for date: Date) -> AnyPublisher<WorkLog, DozyError> {
        fetchOrCreateCallCount += 1
        if let error = stubbedFetchError { return Fail(error: error).eraseToAnyPublisher() }
        if let stubbedLog { return Just(stubbedLog).setFailureType(to: DozyError.self).eraseToAnyPublisher() }
        let log = WorkLog(date: date)
        stubbedLog = log
        createdLogCount += 1
        return Just(log).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func save(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        saveCallCount += 1
        if let error = stubbedSaveError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func delete(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

// MARK: - MockPeriodCalendarService (#72)

/// 기간 조회만 쓰는 캘린더 서비스. 호출 범위를 기록한다.
final class MockPeriodCalendarService: CalendarServiceProtocol {
    var stubbedEvents: [CalendarEvent] = []
    var stubbedError: DozyError? = nil
    private(set) var rangeCalls: [(start: Date, end: Date)] = []

    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        rangeCalls.append((start, end))
        if let error = stubbedError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(stubbedEvents).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        Just(true).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
}

// MARK: - MockQueryParsingService (#72)

final class MockQueryParsingService: QueryParsingServiceProtocol {
    var stubbedIntent = SearchQueryIntent()
    /// 입력별 결과. 없으면 stubbedIntent.
    var stubbedIntents: [String: SearchQueryIntent] = [:]
    private(set) var receivedTexts: [String] = []
    private(set) var receivedCategories: [String] = []

    func parseQuery(from text: String, referenceDate: Date, categories: [String]) async -> SearchQueryIntent {
        receivedTexts.append(text)
        receivedCategories = categories
        return stubbedIntents[text] ?? stubbedIntent
    }
}

// MARK: - MockPushTokenService (#95)

final class MockPushTokenService: PushTokenServiceProtocol {
    var signedIn = true
    var stubbedError: Error? = nil
    private(set) var registered: [(token: String, environment: String, sharedEnabled: Bool)] = []
    private(set) var unregistered: [String] = []

    func isSignedIn() async -> Bool { signedIn }

    func register(token: String, platform: String, environment: String, sharedNotificationsEnabled: Bool) async throws {
        if let stubbedError { throw stubbedError }
        registered.append((token, environment, sharedNotificationsEnabled))
    }

    func unregister(token: String) async throws {
        if let stubbedError { throw stubbedError }
        unregistered.append(token)
    }
}

// MARK: - MockAnalyticsService (#90)

final class MockAnalyticsService: AnalyticsServiceProtocol {
    private(set) var trackedEvents: [AnalyticsEvent] = []
    private(set) var userProperties: [AnalyticsUserProperty: String?] = [:]
    private(set) var collectionEnabled: Bool?

    func track(_ event: AnalyticsEvent) { trackedEvents.append(event) }
    func setUserProperty(_ value: String?, for property: AnalyticsUserProperty) { userProperties[property] = value }
    func setCollectionEnabled(_ enabled: Bool) { collectionEnabled = enabled }
}

// MARK: - MockSharedCalendarService (#90)

final class MockSharedCalendarService: SharedCalendarServiceProtocol {
    var stubbedError: DozyError? = nil

    private func result<T>(_ value: T) -> AnyPublisher<T, DozyError> {
        if let error = stubbedError { return Fail(error: error).eraseToAnyPublisher() }
        return Just(value).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }

    func create(name: String) -> AnyPublisher<SharedCalendarCreationResult, DozyError> {
        result(SharedCalendarCreationResult(calendarID: "cal-1", inviteCode: "ABC123", inviteCodeExpiresAt: Date()))
    }
    func join(inviteCode: String) -> AnyPublisher<SharedCalendarJoinResult, DozyError> {
        result(SharedCalendarJoinResult(calendarID: "cal-1"))
    }
    func regenerateInviteCode(calendarID: String) -> AnyPublisher<SharedCalendarInviteCodeResult, DozyError> {
        result(SharedCalendarInviteCodeResult(inviteCode: "XYZ789", inviteCodeExpiresAt: Date()))
    }
    func fetchMyCalendars() -> AnyPublisher<[SharedCalendar], DozyError> { result([]) }
    func fetchMembers(calendarID: String) -> AnyPublisher<[SharedCalendarMember], DozyError> { result([]) }
    func leave(calendarID: String) -> AnyPublisher<Void, DozyError> { result(()) }
    func delete(calendarID: String) -> AnyPublisher<Void, DozyError> { result(()) }
    func updateNickname(calendarID: String, nickname: String) -> AnyPublisher<Void, DozyError> { result(()) }
    func updateCalendarName(calendarID: String, name: String) -> AnyPublisher<Void, DozyError> { result(()) }
    func uploadCalendarImage(calendarID: String, jpegData: Data, previousPath: String?) -> AnyPublisher<String, DozyError> { result("path") }
    func removeCalendarImage(calendarID: String, path: String) -> AnyPublisher<Void, DozyError> { result(()) }
}

// MARK: - MockCrashReportingService (#117)

nonisolated final class MockCrashReportingService: CrashReportingServiceProtocol {
    private(set) var recorded: [(error: Error, context: String)] = []
    private(set) var logs: [String] = []
    private(set) var collectionEnabled: Bool?

    func record(_ error: Error, context: String) { recorded.append((error, context)) }
    func log(_ message: String) { logs.append(message) }
    func setCollectionEnabled(_ enabled: Bool) { collectionEnabled = enabled }
}
