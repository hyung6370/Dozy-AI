//
//  WorkLogRepository.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - Data Layer]
//  WorkLogRepositoryProtocol의 SwiftData 구현체입니다.
//  ModelContainer를 생성자에서 주입받아 항상 유효한 ModelContext를 보장합니다.
//  mainContext는 @MainActor 전용이므로 Task { @MainActor in }으로 감쌉니다.

import Foundation
import Combine
import SwiftData

final class WorkLogRepository: WorkLogRepositoryProtocol {

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - 특정 날짜 WorkLog 조회

    func fetchLog(for date: Date) -> AnyPublisher<WorkLog?, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let targetDate = date.startOfDay
                let nextDay = date.startOfNextDay

                let descriptor = FetchDescriptor<WorkLog>(
                    predicate: #Predicate<WorkLog> { log in
                        log.date >= targetDate && log.date < nextDay
                    }
                )

                do {
                    let results = try context.fetch(descriptor)
                    promise(.success(results.first))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 최근 N일 WorkLog 목록 조회

    func fetchRecentLogs(days: Int) -> AnyPublisher<[WorkLog], DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let startDate = Date().daysAgo(days).startOfDay

                var descriptor = FetchDescriptor<WorkLog>(
                    predicate: #Predicate<WorkLog> { log in
                        log.date >= startDate
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                descriptor.fetchLimit = days

                do {
                    let results = try context.fetch(descriptor)
                    promise(.success(results))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - WorkLog 저장 (삽입 또는 업데이트)

    func save(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                do {
                    // 이미 tracked된 모델에 대한 insert는 no-op
                    context.insert(log)
                    try context.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - WorkLog 삭제

    func delete(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                do {
                    context.delete(log)
                    try context.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
