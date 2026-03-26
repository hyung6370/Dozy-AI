//
//  ReminderService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - Data Layer]
//  ReminderServiceProtocol의 EventKit 구현체입니다.
//  EKReminder → TaskItem 변환(Mapping)을 이 파일 내 private extension으로 처리합니다.
//  Domain 모델(TaskItem)은 EventKit을 전혀 모릅니다.

import Foundation
import Combine
import EventKit

final class ReminderService: ReminderServiceProtocol {

    private let eventStore = EKEventStore()

    // MARK: - 권한 요청

    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        Future { [eventStore] promise in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    promise(.failure(.reminderFetchFailed(underlying: error)))
                } else {
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 완료된 리마인더 조회

    func fetchCompletedReminders(for date: Date) -> AnyPublisher<[TaskItem], DozyError> {
        requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[TaskItem], DozyError> in
                Future { promise in
                    let predicate = eventStore.predicateForCompletedReminders(
                        withCompletionDateStarting: date.startOfDay,
                        ending: date.startOfNextDay,
                        calendars: nil
                    )

                    eventStore.fetchReminders(matching: predicate) { reminders in
                        let tasks = (reminders ?? [])
                            .map { $0.toTaskItem() }           // ← Mapper 사용
                            .sorted {
                                ($0.completedDate ?? .distantPast) < ($1.completedDate ?? .distantPast)
                            }
                        promise(.success(tasks))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 미완료 리마인더 조회

    func fetchPendingReminders() -> AnyPublisher<[TaskItem], DozyError> {
        requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[TaskItem], DozyError> in
                Future { promise in
                    let predicate = eventStore.predicateForIncompleteReminders(
                        withDueDateStarting: nil,
                        ending: nil,
                        calendars: nil
                    )

                    eventStore.fetchReminders(matching: predicate) { reminders in
                        let tasks = (reminders ?? [])
                            .map { $0.toTaskItem() }           // ← Mapper 사용
                            .sorted { lhs, rhs in
                                if lhs.priority != rhs.priority {
                                    return lhs.priority < rhs.priority
                                }
                                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
                            }
                        promise(.success(tasks))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    private func requestAccessIfNeeded() -> AnyPublisher<Void, DozyError> {
        Future { [eventStore] promise in
            let status = EKEventStore.authorizationStatus(for: .reminder)

            switch status {
            case .fullAccess, .authorized:
                promise(.success(()))

            case .notDetermined:
                eventStore.requestFullAccessToReminders { granted, _ in
                    if granted {
                        promise(.success(()))
                    } else {
                        promise(.failure(.reminderAccessDenied))
                    }
                }

            case .denied, .restricted, .writeOnly:
                promise(.failure(.reminderAccessDenied))

            @unknown default:
                promise(.failure(.reminderAccessDenied))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - EKReminder → TaskItem Mapper
// Domain 모델이 EventKit을 몰라도 되도록,
// 변환 로직을 Data 계층(이 파일) 안에 캡슐화합니다.

private extension EKReminder {
    func toTaskItem() -> TaskItem {
        TaskItem(
            id: calendarItemIdentifier,
            title: title ?? "제목 없음",
            isCompleted: isCompleted,
            completedDate: completionDate,
            dueDate: dueDateComponents?.date,
            priority: priority,
            listName: calendar?.title ?? "",
            notes: notes
        )
    }
}
