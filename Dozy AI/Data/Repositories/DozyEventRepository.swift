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
import OSLog

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
                    let filtered = await Self.filterByCurrentAccount(all)
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
                    await Self.upsertToSupabase(event)
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
                    // 로그아웃 직후 clearAllLocalData 가 race 로 로컬을 비우는 동안
                    // fire-and-forget Task 가 supabase.auth.session 가드에 막히거나
                    // 네트워크가 끊겨 메모/필드가 Supabase 에 영영 안 올라가던 버그가 있어
                    // upsert 를 inline await 로 보장.
                    await Self.upsertToSupabase(event)
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
                    await Self.upsertToSupabase(event)
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
                    for event in touched {
                        await Self.upsertToSupabase(event)
                    }
                    promise(.success(()))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteExternalMirrors(ids: [String]) -> AnyPublisher<Void, DozyError> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                guard !ids.isEmpty else { promise(.success(())); return }
                let context = modelContainer.mainContext
                let idSet = Set(ids)
                let predicate = #Predicate<DozyEvent> { idSet.contains($0.id) }
                let descriptor = FetchDescriptor<DozyEvent>(predicate: predicate)
                let events = (try? context.fetch(descriptor)) ?? []
                let deletedIDs = events.map(\.id)
                for event in events { context.delete(event) }
                do {
                    try context.save()
                    Task {
                        // Supabase 배치 delete — Realtime DELETE가 파트너 기기로 전파됨.
                        try? await supabase.from("dozy_events")
                            .delete()
                            .in("id", values: deletedIDs)
                            .execute()
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
        guard let currentUserID = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
            Logger.sync.warning("⚠️ DozyEvent upsert skipped — no auth session (event id: \(event.id))")
            return
        }
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
            latitude: event.latitude,
            longitude: event.longitude,
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
        do {
            try await supabase.from("dozy_events").upsert(row).execute()
        } catch {
            Logger.sync.error("❌ DozyEvent upsert 실패 (id: \(event.id)): \(error.localizedDescription)")
        }
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
                    let filtered = await Self.filterByCurrentAccount(all)
                    promise(.success(filtered))
                } catch {
                    promise(.failure(.saveFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 현재 로그인 계정 기준으로 이벤트 필터링.
    /// - 로그인 안 된 상태(userID nil): 모든 이벤트 차단. clearAllLocalData
    ///   가 race 로 못 따라갔거나 일부 잔여가 있어도 그리드엔 안 보이게.
    /// - 개인 이벤트(sharedCalendarID == nil): ownerID 가 현재 userID 와 일치하거나
    ///   nil(아직 서버 업로드 전)일 때만 노출. 다른 계정으로 로그인했을 때
    ///   이전 계정의 SwiftData 잔여 데이터를 차단한다.
    /// - 공유 이벤트(sharedCalendarID != nil): 가입한 모든 공유 캘린더의 이벤트를
    ///   그대로 통과 (단일 active 제약은 멀티 가시성 필터로 이전됨).
    @MainActor
    private static func filterByCurrentAccount(_ events: [DozyEvent]) async -> [DozyEvent] {
        guard let userID = try? await supabase.auth.session.user.id.uuidString.lowercased()
        else { return [] }
        return events.filter { event in
            guard event.sharedCalendarID == nil else { return true }
            if let oid = event.ownerID, oid != userID { return false }
            return true
        }
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
    let latitude: Double?
    let longitude: Double?
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
        case location, latitude, longitude, notes
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
