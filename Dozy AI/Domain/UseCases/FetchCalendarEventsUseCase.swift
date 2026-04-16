//
//  FetchTodayDataUseCase.swift
//  Dozy AI
//
//  [Clean Architecture - UseCase]
//  오늘의 캘린더 이벤트 + 완료된 리마인더 + 미완료 리마인더를
//  동시에 가져오는 비즈니스 로직을 캡슐화합니다.
//  ViewModel은 이 UseCase만 호출하며, 서비스를 직접 참조하지 않습니다.

import Foundation
import Combine

// MARK: - Result Type

struct FetchTodayDataResult {
    let events: [CalendarEvent]
    let completedTasks: [TaskItem]
    let pendingTasks: [TaskItem]
}

// MARK: - UseCase

final class FetchTodayDataUseCase {

    private let calendarService: CalendarServiceProtocol
    private let reminderService: ReminderServiceProtocol

    init(
        calendarService: CalendarServiceProtocol,
        reminderService: ReminderServiceProtocol
    ) {
        self.calendarService = calendarService
        self.reminderService = reminderService
    }

    /// 오늘의 모든 데이터를 병렬로 가져옵니다
    func execute() -> AnyPublisher<FetchTodayDataResult, DozyError> {
        Publishers.CombineLatest3(
            calendarService.fetchTodayEvents(),
            reminderService.fetchCompletedReminders(for: Date()),
            reminderService.fetchPendingReminders()
        )
        .map { events, completed, pending in
            FetchTodayDataResult(
                events: events,
                completedTasks: completed,
                pendingTasks: pending
            )
        }
        .eraseToAnyPublisher()
    }
}
