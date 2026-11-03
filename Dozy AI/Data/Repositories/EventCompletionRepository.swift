//
//  EventCompletionRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import SwiftData

final class EventCompletionRepository: EventCompletionRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private var context: ModelContext { modelContainer.mainContext }

    func fetchCompletions(for eventIDs: [String], on date: Date) async throws(DozyError) -> [String: Bool] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let all: [EventCompletion]
        do {
            all = try context.fetch(FetchDescriptor<EventCompletion>())
        } catch {
            throw .saveFailed(underlying: error)
        }
        let set = Set(eventIDs)
        var dict: [String: Bool] = [:]
        for completion in all where set.contains(completion.eventID)
            && completion.eventDate >= dayStart && completion.eventDate < dayEnd {
            let key = Self.completionKey(eventID: completion.eventID, date: completion.eventDate)
            dict[key] = completion.isCompleted
        }
        return dict
    }

    static func completionKey(eventID: String, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return "\(eventID)_\(Int(day.timeIntervalSince1970))"
    }

    func fetchCompletions(from start: Date, to end: Date) async throws(DozyError) -> [EventCompletion] {
        do {
            let all = try context.fetch(FetchDescriptor<EventCompletion>())
            return all.filter { $0.eventDate >= start && $0.eventDate < end && $0.isCompleted }
        } catch {
            throw .saveFailed(underlying: error)
        }
    }

    func toggle(eventID: String, eventDate: Date) async throws(DozyError) -> Bool {
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
                return existing.isCompleted
            }
            let new = EventCompletion(eventID: eventID, eventDate: dayStart)
            new.isCompleted = true
            context.insert(new)
            try context.save()
            return true
        } catch {
            throw .saveFailed(underlying: error)
        }
    }
}
