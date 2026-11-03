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
import EventKit

final class ReminderService: ReminderServiceProtocol {

    private let eventStore = EKEventStore()

    // MARK: - 권한 요청

    func requestAccess() async throws(DozyError) -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            throw .reminderFetchFailed(underlying: error)
        }
    }

    // MARK: - 완료된 리마인더 조회

    func fetchCompletedReminders(for date: Date) async throws(DozyError) -> [TaskItem] {
        try await requestAccessIfNeeded()
        let predicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: date.startOfDay,
            ending: date.startOfNextDay,
            calendars: nil
        )
        return await fetchTasks(matching: predicate).sorted {
            ($0.completedDate ?? .distantPast) < ($1.completedDate ?? .distantPast)
        }
    }

    // MARK: - 미완료 리마인더 조회

    func fetchPendingReminders() async throws(DozyError) -> [TaskItem] {
        try await requestAccessIfNeeded()
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        return await fetchTasks(matching: predicate).sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
        }
    }

    // MARK: - Private Helpers

    /// `fetchReminders` 는 async 판이 없다. 콜백은 EventKit 내부 큐에서 불리므로 `@Sendable` 로 두고
    /// (메인 액터 클로저로 추론되면 Swift 6 런타임 격리 검사로 죽는다, #152) 그 안에서 값 타입으로 바꿔 넘긴다.
    private func fetchTasks(matching predicate: NSPredicate) async -> [TaskItem] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[TaskItem], Never>) in
            eventStore.fetchReminders(matching: predicate) { @Sendable reminders in
                continuation.resume(returning: (reminders ?? []).map { $0.toTaskItem() })
            }
        }
    }

    private func requestAccessIfNeeded() async throws(DozyError) {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized:
            return
        case .notDetermined:
            let granted = (try? await eventStore.requestFullAccessToReminders()) ?? false
            guard granted else { throw .reminderAccessDenied }
        case .denied, .restricted, .writeOnly:
            throw .reminderAccessDenied
        @unknown default:
            throw .reminderAccessDenied
        }
    }
}

// MARK: - EKReminder → TaskItem Mapper
// Domain 모델이 EventKit을 몰라도 되도록,
// 변환 로직을 Data 계층(이 파일) 안에 캡슐화합니다.

private extension EKReminder {
    nonisolated func toTaskItem() -> TaskItem {
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
