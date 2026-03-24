//
//  ReminderService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

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
        
        return requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[TaskItem], DozyError> in
                Future { promise in
                    // 완료된 리마인더를 날짜 범위로 검색
                    let predicate = eventStore.predicateForCompletedReminders(
                        withCompletionDateStarting: date.startOfDay,
                        ending: date.startOfNextDay,
                        calendars: nil
                    )
                    
                    eventStore.fetchReminders(matching: predicate) { reminders in
                        let tasks = (reminders ?? [])
                            .map { TaskItem(from: $0) }
                            .sorted { ($0.completedDate ?? .distantPast) < ($1.completedDate ?? .distantPast) }
                        
                        promise(.success(tasks))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 미완료 리마인더 조회
    func fetchPendingReminders() -> AnyPublisher<[TaskItem], DozyError> {
        
        return requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[TaskItem], DozyError> in
                Future { promise in
                    let predicate = eventStore.predicateForIncompleteReminders(
                        withDueDateStarting: nil,
                        ending: nil,
                        calendars: nil
                    )
                    
                    eventStore.fetchReminders(matching: predicate) { reminders in
                        let tasks = (reminders ?? [])
                            .map { TaskItem(from: $0) }
                            // 우선순위 높은 것 먼저, 같으면 마감일 빠른 것 먼저
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
    
    // MARK: - private Helpers
    
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
