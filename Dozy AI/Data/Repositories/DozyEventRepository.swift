//
//  DozyEventRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine
import SwiftData

final class DozyEventRepository: DozyEventRepositoryProtocol {
    
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func fetchEvents(from startDate: Date, to endDate: Date) -> AnyPublisher<[DozyEvent], DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let start = startDate
                let end = endDate
                let predicate = #Predicate<DozyEvent> { $0.startDate < end && $0.endDate > start }
                let descriptor = FetchDescriptor<DozyEvent>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.startDate)]
                )
                do {
                    promise(.success(try context.fetch(descriptor)))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func save(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                context.insert(event)
                do {
                    try context.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func update(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                event.updatedAt = Date()
                do {
                    try modelContainer.mainContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func delete(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                context.delete(event)
                do {
                    try context.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchAllRecurring() -> AnyPublisher<[DozyEvent], DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let predicate = #Predicate<DozyEvent> { $0.recurrenceRule != "none" }
                let descriptor = FetchDescriptor<DozyEvent>(predicate: predicate)
                do {
                    promise(.success(try context.fetch(descriptor)))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
