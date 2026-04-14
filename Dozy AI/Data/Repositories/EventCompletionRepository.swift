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
    
    func fetchCompletions(for eventIDs: [String], on date: Date) -> AnyPublisher<[String: Bool], DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let cal = Calendar.current
                let dayStart = cal.startOfDay(for: date)
                let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                do {
                    let all = try context.fetch(FetchDescriptor<EventCompletion>())
                    let set = Set(eventIDs)
                    var dict: [String: Bool] = [:]
                    for completion in all where set.contains(completion.eventID)
                        && completion.eventDate >= dayStart && completion.eventDate < dayEnd {
                        let key = Self.completionKey(eventID: completion.eventID, date: completion.eventDate)
                        dict[key] = completion.isCompleted
                    }
                    promise(.success(dict))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    static func completionKey(eventID: String, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return "\(eventID)_\(Int(day.timeIntervalSince1970))"
    }
    
    func fetchCompletions(from start: Date, to end: Date) -> AnyPublisher<[EventCompletion], DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                do {
                    let all = try context.fetch(FetchDescriptor<EventCompletion>())
                    let filtered = all.filter { $0.eventDate >= start && $0.eventDate < end && $0.isCompleted }
                    promise(.success(filtered))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func toggle(eventID: String, eventDate: Date) -> AnyPublisher<Bool, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let id = eventID
                let cal = Calendar.current
                let dayStart = cal.startOfDay(for: eventDate)
                let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                let pred = #Predicate<EventCompletion> { $0.eventID == id }
                do {
                    // eventID로 먼저 좁히고, 날짜는 메모리에서 필터 (SwiftData 복합 predicate 제한)
                    let existing = try context.fetch(FetchDescriptor<EventCompletion>(predicate: pred))
                        .first { $0.eventDate >= dayStart && $0.eventDate < dayEnd }
                    if let existing {
                        existing.isCompleted.toggle()
                        existing.updatedAt = Date()
                        try context.save()
                        promise(.success(existing.isCompleted))
                    } else {
                        let new = EventCompletion(eventID: eventID, eventDate: dayStart)
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
