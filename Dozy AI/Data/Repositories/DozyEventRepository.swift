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

                let predicate = #Predicate<DozyEvent> {
                    $0.startDate < end && $0.endDate >= start
                }
                let descriptor = FetchDescriptor<DozyEvent>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.startDate)]
                )
                do {
                    let all = try context.fetch(descriptor)
                    let activeID = ActiveSharedCalendarStore.shared.activeCalendarID
                    let filtered = all.filter { event in
                        // 개인 이벤트는 항상 표시
                        if event.sharedCalendarID == nil { return true }
                        // 공유 이벤트는 활성 캘린더와 일치할 때만
                        return event.sharedCalendarID == activeID
                    }
                    promise(.success(filtered))
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

    func mirrorExternalEvent(
        _ origin: CalendarEvent,
        to sharedCalendarID: String
    ) -> AnyPublisher<DozyEvent, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                guard let ownerID = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
                    promise(.failure(.dataNotFound))
                    return
                }
                let context = modelContainer.mainContext
                let originSourceRaw = origin.source.rawValue
                let originID = origin.id

                // 같은 원본 + 소유자 조합의 스냅샷이 이미 있으면 공유 대상만 갱신.
                let predicate = #Predicate<DozyEvent> {
                    $0.ownerID == ownerID
                        && $0.externalSource == originSourceRaw
                        && $0.externalEventID == originID
                }
                let descriptor = FetchDescriptor<DozyEvent>(predicate: predicate)
                let existing = (try? context.fetch(descriptor))?.first

                let now = Date()
                let event: DozyEvent
                if let existing {
                    existing.sharedCalendarID = sharedCalendarID
                    existing.title = origin.title
                    existing.startDate = origin.startDate
                    existing.endDate = origin.endDate
                    existing.isAllDay = origin.isAllDay
                    existing.location = origin.location
                    existing.notes = origin.notes
                    existing.colorHex = origin.calendarColorHex
                    existing.externalDeleted = false
                    existing.externalLastSyncedAt = now
                    existing.updatedAt = now
                    event = existing
                } else {
                    let snapshot = DozyEvent(
                        title: origin.title,
                        startDate: origin.startDate,
                        endDate: origin.endDate,
                        isAllDay: origin.isAllDay,
                        location: origin.location,
                        notes: origin.notes,
                        colorHex: origin.calendarColorHex,
                        sharedCalendarID: sharedCalendarID,
                        ownerID: ownerID,
                        externalSource: origin.source.rawValue,
                        externalEventID: origin.id,
                        externalLastSyncedAt: now,
                        externalDeleted: false
                    )
                    context.insert(snapshot)
                    event = snapshot
                }

                do {
                    try context.save()
                    Task { await Self.upsertToSupabase(event) }
                    promise(.success(event))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchMyExternalMirrors() -> AnyPublisher<[DozyEvent], DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                guard let ownerID = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
                    promise(.success([]))
                    return
                }
                let context = modelContainer.mainContext
                let predicate = #Predicate<DozyEvent> {
                    $0.ownerID == ownerID && $0.externalSource != nil
                }
                let descriptor = FetchDescriptor<DozyEvent>(predicate: predicate)
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

    func applyExternalMirrorReconcile(
        updates: [ExternalMirrorUpdate],
        deletedIDs: [String]
    ) -> AnyPublisher<Void, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let touchedIDs = Set(updates.map(\.id)).union(deletedIDs)
                guard !touchedIDs.isEmpty else { promise(.success(())); return }
                let idArray = Array(touchedIDs)
                let predicate = #Predicate<DozyEvent> { idArray.contains($0.id) }
                let descriptor = FetchDescriptor<DozyEvent>(predicate: predicate)
                let events = (try? context.fetch(descriptor)) ?? []
                let byID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
                let now = Date()
                var touched: [DozyEvent] = []

                for update in updates {
                    guard let event = byID[update.id] else { continue }
                    event.title = update.title
                    event.startDate = update.startDate
                    event.endDate = update.endDate
                    event.isAllDay = update.isAllDay
                    event.location = update.location
                    event.notes = update.notes
                    event.colorHex = update.colorHex
                    event.externalDeleted = false
                    event.externalLastSyncedAt = now
                    event.updatedAt = now
                    touched.append(event)
                }
                for id in deletedIDs {
                    guard let event = byID[id], !event.externalDeleted else { continue }
                    event.externalDeleted = true
                    event.externalLastSyncedAt = now
                    event.updatedAt = now
                    touched.append(event)
                }

                guard !touched.isEmpty else { promise(.success(())); return }
                do {
                    try context.save()
                    Task {
                        for event in touched {
                            await Self.upsertToSupabase(event)
                        }
                    }
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
        guard let currentUserID = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }
        // 파트너 이벤트를 편집(메모 등)할 때 원래 소유자(user_id) 보존.
        // 이렇게 해야 Supabase 기록이 유지되고, 파트너 디바이스의 realtime UPDATE 가드를 통과한다.
        let row = DozyEventRow(
            id: event.id,
            userID: event.ownerID ?? currentUserID,
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
            priority: event.priority,
            isPinned: event.isPinned,
            category: event.category,
            sharedCalendarID: event.sharedCalendarID,
            externalSource: event.externalSource,
            externalEventID: event.externalEventID,
            externalLastSyncedAt: event.externalLastSyncedAt,
            externalDeleted: event.externalDeleted,
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
                    let all = try context.fetch(descriptor)
                    let activeID = ActiveSharedCalendarStore.shared.activeCalendarID
                    let filtered = all.filter { event in
                        if event.sharedCalendarID == nil { return true }
                        return event.sharedCalendarID == activeID
                    }
                    promise(.success(filtered))
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
    let priority: Int
    let isPinned: Bool
    let category: String
    let sharedCalendarID: String?
    let externalSource: String?
    let externalEventID: String?
    let externalLastSyncedAt: Date?
    let externalDeleted: Bool
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
        case priority
        case isPinned = "is_pinned"
        case category
        case sharedCalendarID = "shared_calendar_id"
        case externalSource = "external_source"
        case externalEventID = "external_event_id"
        case externalLastSyncedAt = "external_last_synced_at"
        case externalDeleted = "external_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
