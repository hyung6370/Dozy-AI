//
//  WorkLogRepository.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - Data Layer]
//  WorkLogRepositoryProtocol의 SwiftData 구현체입니다.
//  ModelContainer를 생성자에서 주입받아 항상 유효한 ModelContext를 보장합니다.
//  mainContext는 @MainActor 전용 — 클래스 기본 격리가 MainActor 라 async 메서드가 그대로 메인에서 돈다 (#153).

import Foundation
import SwiftData

final class WorkLogRepository: WorkLogRepositoryProtocol {

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private var context: ModelContext { modelContainer.mainContext }

    // MARK: - 특정 날짜 WorkLog 조회

    func fetchLog(for date: Date) async throws(DozyError) -> WorkLog? {
        do {
            return try context.fetch(Self.dayDescriptor(for: date)).first
        } catch {
            throw .saveFailed(underlying: error)
        }
    }

    // MARK: - 최근 N일 WorkLog 목록 조회

    func fetchRecentLogs(days: Int) async throws(DozyError) -> [WorkLog] {
        let startDate = Date().daysAgo(days).startOfDay
        var descriptor = FetchDescriptor<WorkLog>(
            predicate: #Predicate<WorkLog> { log in
                log.date >= startDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = days
        do {
            return try context.fetch(descriptor)
        } catch {
            throw .saveFailed(underlying: error)
        }
    }

    // MARK: - WorkLog 저장 (삽입 또는 업데이트)

    func fetchOrCreateLog(for date: Date) async throws(DozyError) -> WorkLog {
        // 조회 → 생성 → 저장 사이에 await 를 두지 않는다. 메인 액터에서 한 번에 끝나야 그 사이에 다른 호출
        // (일정 로딩 · 메모 추가)이 끼어들어 같은 날 WorkLog 가 둘 생기는 일이 없다.
        do {
            if let existing = try context.fetch(Self.dayDescriptor(for: date)).first {
                return existing
            }
            let log = WorkLog(date: date)
            context.insert(log)
            try context.save()
            return log
        } catch {
            throw .saveFailed(underlying: error)
        }
    }

    func save(_ log: WorkLog) async throws(DozyError) {
        do {
            // 이미 tracked된 모델에 대한 insert는 no-op
            context.insert(log)
            try context.save()
        } catch {
            throw .saveFailed(underlying: error)
        }
    }

    // MARK: - WorkLog 삭제

    func delete(_ log: WorkLog) async throws(DozyError) {
        do {
            context.delete(log)
            try context.save()
        } catch {
            throw .saveFailed(underlying: error)
        }
    }

    // MARK: - Private

    private static func dayDescriptor(for date: Date) -> FetchDescriptor<WorkLog> {
        let targetDate = date.startOfDay
        let nextDay = date.startOfNextDay
        return FetchDescriptor<WorkLog>(
            predicate: #Predicate<WorkLog> { log in
                log.date >= targetDate && log.date < nextDay
            }
        )
    }
}
