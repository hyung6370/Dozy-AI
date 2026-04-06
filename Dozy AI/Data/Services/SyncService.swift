//
//  SyncService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/6/26.
//

import Foundation
import Combine
import SwiftData
import Supabase

final class SyncService {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - 전체 동기화 (로그인 직후 호출)
    
    func syncAll(userID: String) -> AnyPublisher<Void, DozyError> {
        Publishers.Zip3(
            uploadDozyEvents(userID: userID),
            uploadEventCompletions(userID: userID),
            uploadWorkLogs(userID: userID)
        )
        .flatMap { [weak self] _ -> AnyPublisher<Void, DozyError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return Publishers.Zip3(
                self.downloadDozyEvents(userID: userID),
                self.downloadEventCompletions(userID: userID),
                self.downloadWorkLogs(userID: userID)
            )
            .map { _ in }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Upload
    
    private func uploadDozyEvents(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let events = try self.modelContext.fetch(FetchDescriptor<DozyEvent>())
                    let rows = events.map { event in
                        DozyEventRow(
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
                            isCompleted: event.isCompleted,
                            createdAt: event.createdAt,
                            updatedAt: event.updatedAt
                        )
                    }
                    guard !rows.isEmpty else { promise(.success(())); return }
                    try await supabase.from("dozy_events").upsert(rows).execute()
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func uploadEventCompletions(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let completions = try self.modelContext.fetch(FetchDescriptor<EventCompletion>())
                    let rows = completions.map { c in
                        EventCompletionRow(
                            userID: userID,
                            eventID: c.eventID,
                            isCompleted: c.isCompleted,
                            eventDate: c.eventDate,
                            updatedAt: c.updatedAt
                        )
                    }
                    guard !rows.isEmpty else { promise(.success(())); return }
                    try await supabase.from("event_completions").upsert(rows, onConflict: "user_id, event_id, event_date").execute()
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func uploadWorkLogs(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let logs = try self.modelContext.fetch(FetchDescriptor<WorkLog>())
                    let rows = logs.map { log in
                        WorkLogRow(
                            id: log.id,
                            userID: userID,
                            date: log.date,
                            rawEventTitles: log.rawEventTitles,
                            rawEventDetails: log.rawEventDetails,
                            completedTaskTitles: log.completedTaskTitles,
                            memos: log.memos,
                            aiSummary: log.aiSummary,
                            highlights: log.highlights,
                            nextActions: log.nextActions,
                            category: log.category,
                            productivityScore: log.productivityScore,
                            createdAt: log.createdAt,
                            updatedAt: log.updatedAt
                        )
                    }
                    guard !rows.isEmpty else { promise(.success(())); return }
                    try await supabase.from("work_logs").upsert(rows, onConflict: "user_id, date").execute()
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Download
    
    private func downloadDozyEvents(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let rows: [DozyEventRow] = try await supabase
                        .from("dozy_events")
                        .select()
                        .eq("user_id", value: userID)
                        .execute()
                        .value
                    let existing = try self.modelContext.fetch(FetchDescriptor<DozyEvent>())
                    let existingIDs = Set(existing.map { $0.id })
                    for row in rows where !existingIDs.contains(row.id) {
                        let event = DozyEvent(
                            id: row.id,
                            title: row.title,
                            startDate: row.startDate,
                            endDate: row.endDate,
                            isAllDay: row.isAllDay,
                            location: row.location,
                            notes: row.notes,
                            colorHex: row.colorHex,
                            recurrenceRule: row.recurrenceRule,
                            recurrenceEndDate: row.recurrenceEndDate,
                            notificationMinutesBefore: row.notificationMinutesBefore
                        )
                        event.isCompleted = row.isCompleted
                        self.modelContext.insert(event)
                    }
                    try self.modelContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func downloadEventCompletions(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let rows: [EventCompletionRow] = try await supabase
                        .from("event_completions")
                        .select()
                        .eq("user_id", value: userID)
                        .execute()
                        .value
                    let existing = try self.modelContext.fetch(FetchDescriptor<EventCompletion>())
                    for row in rows {
                        if let local = existing.first(where: { $0.eventID == row.eventID && Calendar.current.isDate($0.eventDate, inSameDayAs: row.eventDate) }) {
                            local.isCompleted = row.isCompleted
                        } else {
                            let c = EventCompletion(eventID: row.eventID, eventDate: row.eventDate)
                            c.isCompleted = row.isCompleted
                            self.modelContext.insert(c)
                        }
                    }
                    try self.modelContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func downloadWorkLogs(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let rows: [WorkLogRow] = try await supabase
                        .from("work_logs")
                        .select()
                        .eq("user_id", value: userID)
                        .execute()
                        .value
                    let existing = try self.modelContext.fetch(FetchDescriptor<WorkLog>())
                    let existingIDs = Set(existing.map { $0.id })
                    for row in rows where !existingIDs.contains(row.id) {
                        let log = WorkLog(date: row.date)
                        log.id = row.id
                        log.rawEventTitles = row.rawEventTitles
                        log.rawEventDetails = row.rawEventDetails
                        log.completedTaskTitles = row.completedTaskTitles
                        log.memos = row.memos
                        log.aiSummary = row.aiSummary
                        log.highlights = row.highlights
                        log.nextActions = row.nextActions
                        log.category = row.category
                        log.productivityScore = row.productivityScore
                        self.modelContext.insert(log)
                    }
                    try self.modelContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Supabase Row DTOs

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
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct EventCompletionRow: Codable {
    let userID: String
    let eventID: String
    let isCompleted: Bool
    let eventDate: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case eventID = "event_id"
        case isCompleted = "is_completed"
        case eventDate = "event_date"
        case updatedAt = "updated_at"
    }
}

private struct WorkLogRow: Codable {
    let id: UUID
    let userID: String
    let date: Date
    let rawEventTitles: [String]
    let rawEventDetails: [String]
    let completedTaskTitles: [String]
    let memos: [String]
    let aiSummary: String
    let highlights: [String]
    let nextActions: [String]
    let category: String
    let productivityScore: Double?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case date
        case rawEventTitles = "raw_event_titles"
        case rawEventDetails = "raw_event_details"
        case completedTaskTitles = "completed_task_titles"
        case memos
        case aiSummary = "ai_summary"
        case highlights
        case nextActions = "next_actions"
        case category
        case productivityScore = "productivity_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
