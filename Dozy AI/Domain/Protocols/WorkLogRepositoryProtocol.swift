//
//  WorkLogRepositoryProtocol.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/24/26.
//

import Foundation
import Combine

protocol WorkLogRepositoryProtocol {
    // 특정 날짜의 WorkLog를 가져온다 (없으면 nil)
    func fetchLog(for date: Date) async throws(DozyError) -> WorkLog?

    // 특정 날짜의 WorkLog 를 가져오고, 없으면 만들어 저장한 뒤 돌려준다 (#137)
    // 조회와 생성을 한 번에 처리해야 동시에 불려도 같은 날 WorkLog 가 둘 생기지 않는다.
    func fetchOrCreateLog(for date: Date) async throws(DozyError) -> WorkLog

    // 최근 N일간의 WorkLog 목록을 가져온다
    func fetchRecentLogs(days: Int) async throws(DozyError) -> [WorkLog]

    // WorkLog를 저장한다 (삽입 또는 업데이트)
    func save(_ log: WorkLog) async throws(DozyError)

    // WorkLog를 삭제한다
    func delete(_ log: WorkLog) async throws(DozyError)
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)

extension WorkLogRepositoryProtocol {
    func fetchLog(for date: Date) -> AnyPublisher<WorkLog?, DozyError> {
        .bridge { () async throws(DozyError) -> WorkLog? in try await self.fetchLog(for: date) }
    }

    func fetchOrCreateLog(for date: Date) -> AnyPublisher<WorkLog, DozyError> {
        .bridge { () async throws(DozyError) -> WorkLog in try await self.fetchOrCreateLog(for: date) }
    }

    func fetchRecentLogs(days: Int) -> AnyPublisher<[WorkLog], DozyError> {
        .bridge { () async throws(DozyError) -> [WorkLog] in try await self.fetchRecentLogs(days: days) }
    }

    func save(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.save(log) }
    }

    func delete(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.delete(log) }
    }
}
