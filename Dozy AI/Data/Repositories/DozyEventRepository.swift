//
//  DozyEventRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine
import SwiftData
import Supabase

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
                    Task { await Self.upsertToSupabase(event) }
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
                    Task { await Self.upsertToSupabase(event) }
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
                let eventID = event.id
                context.delete(event)
                do {
                    try context.save()
                    Task { await Self.deleteFromSupabase(eventID: eventID) }
                    promise(.success(()))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Supabase 즉시 동기화

    private static func upsertToSupabase(_ event: DozyEvent) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let row = DozyEventRow(
            id: event.id,
            userID: userID,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            notes: event.notes,
            colorHex: event.colorHex,
            recurrenceRule: event.recurrenceRule,
            recurrenceEndDate: event.recurrenceEndDate,
            notificationMinutesBefore: event.notificationMinutesBefore,
            memos: event.memos,
            isCompleted: event.isCompleted,
            createdAt: event.createdAt,
            updatedAt: event.updatedAt
        )
        try? await supabase.from("dozy_events").upsert(row).execute()
    }

    private static func deleteFromSupabase(eventID: String) async {
        guard (try? await supabase.auth.session) != nil else { return }
        try? await supabase.from("dozy_events").delete().eq("id", value: eventID).execute()
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

// MARK: - Supabase DTO

private struct DozyEventRow: Codable {
    let id: String
    let userID: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let colorHex: String
    let recurrenceRule: String
    let recurrenceEndDate: Date?
    let notificationMinutesBefore: Int
    let memos: [String]
    let isCompleted: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case isAllDay = "is_all_day"
        case location, notes
        case colorHex = "color_hex"
        case recurrenceRule = "recurrence_rule"
        case recurrenceEndDate = "recurrence_end_date"
        case notificationMinutesBefore = "notification_minutes_before"
        case memos
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
