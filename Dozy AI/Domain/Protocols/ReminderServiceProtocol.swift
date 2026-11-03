//
//  ReminderServiceProtocol.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine

protocol ReminderServiceProtocol {
    // 특정 날짜에 완료된 미리알림을 가져온다
    func fetchCompletedReminders(for date: Date) async throws(DozyError) -> [TaskItem]

    // 미완료 미리알림을 가져온다 (다음 할 일 추천용)
    func fetchPendingReminders() async throws(DozyError) -> [TaskItem]

    // 미리알림 접근 권한을 요청한다
    func requestAccess() async throws(DozyError) -> Bool
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)

extension ReminderServiceProtocol {
    func fetchCompletedReminders(for date: Date) -> AnyPublisher<[TaskItem], DozyError> {
        .bridge { () async throws(DozyError) -> [TaskItem] in try await self.fetchCompletedReminders(for: date) }
    }

    func fetchPendingReminders() -> AnyPublisher<[TaskItem], DozyError> {
        .bridge { () async throws(DozyError) -> [TaskItem] in try await self.fetchPendingReminders() }
    }

    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        .bridge { () async throws(DozyError) -> Bool in try await self.requestAccess() }
    }
}
