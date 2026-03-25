//
//  WorkLogRepository.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine
import SwiftData

final class WorkLogRepository: WorkLogRepositoryProtocol {
    
    // ModelContext는 외부에서 주입받거나, MainActor에서 생성
    private var modelContext: ModelContext?
    
    // ModelContainer를 받아서 context 생성
    @MainActor
    func configure(with container: ModelContainer) {
        self.modelContext = container.mainContext
    }
    
    func fetchLog(for date: Date) -> AnyPublisher<WorkLog?, DozyError> {
        Future { [weak self] promise in
            guard let context = self?.modelContext else {
                promise(.failure(.dataNotFound))
                return
            }
            
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
        .eraseToAnyPublisher()
    }
    
    func fetchRecentLogs(days: Int) -> AnyPublisher<[WorkLog], DozyError> {
        Future { [weak self] promise in
            guard let context = self?.modelContext else {
                promise(.failure(.dataNotFound))
                return
            }
            
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
        .eraseToAnyPublisher()
    }
    
    func save(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let context = self?.modelContext else {
                promise(.failure(.dataNotFound))
                return
            }
            
            do {
                context.insert(log)
                try context.save()
                promise(.success(()))
            } catch {
                promise(.failure(.saveFailed(underlying: error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func delete(_ log: WorkLog) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let context = self?.modelContext else {
                promise(.failure(.dataNotFound))
                return
            }
            
            do {
                context.delete(log)
                try context.save()
                promise(.success(()))
            } catch {
                promise(.failure(.saveFailed(underlying: error)))
            }
        }
        .eraseToAnyPublisher()
    }
}
