//
//  EventCompletionRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine
import SwiftData

final class EventCompletionRepository: EventCompletionRepositoryProtocol {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func fetchCompletions(for eventIDs: [String]) -> AnyPublisher<[String: Bool], DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                do {
                    let all = try context.fetch(FetchDescriptor<EventCompletion>())
                    let set = Set(eventIDs)
                    let dict = Dictionary(uniqueKeysWithValues: all.filter { set.contains($0.eventID) }.map { ($0.eventID, $0.isCompleted) })
                    promise(.success(dict))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func toggle(eventID: String) -> AnyPublisher<Bool, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let id = eventID
                let pred = #Predicate<EventCompletion> { $0.eventID == id }
                do {
                    let existing = try context.fetch(FetchDescriptor<EventCompletion>(predicate: pred)).first
                    if let existing {
                        existing.isCompleted.toggle()
                        existing.updatedAt = Date()
                        try context.save()
                        promise(.success(existing.isCompleted))
                    } else {
                        let new = EventCompletion(eventID: eventID)
                        new.isCompleted = true
                        context.insert(new)
                        try context.save()
                        promise(.success(true))
                    }
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
