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
import OSLog

final class SyncService {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - 전체 동기화 (로그인 직후 호출)

    /// 마지막 동기화 성공 시각을 UserDefaults에 기록하는 키
    static let lastSyncTimestampKey = "sync.lastTimestamp"

    func syncAll(userID: String) -> AnyPublisher<Void, DozyError> {
        // 네트워크 미연결 시 즉시 실패 반환
        guard NetworkMonitor.shared.isConnected else {
            Logger.sync.warning("📵 오프라인 상태 — 동기화 건너뜀")
            return Fail(error: DozyError.networkUnavailable).eraseToAnyPublisher()
        }

        // 업로드 실패는 무시하고 다운로드는 항상 실행
        // (재설치 시 빈 로컬 DB의 임시 데이터가 Supabase 제약 조건에 걸려도 다운로드 체인이 끊기지 않도록)
        let resilientUpload: (AnyPublisher<Void, DozyError>) -> AnyPublisher<Void, DozyError> = { publisher in
            publisher
                .catch { error -> AnyPublisher<Void, DozyError> in
                    Logger.sync.warning("⚠️ 업로드 실패 (무시하고 계속): \(error.localizedDescription)")
                    return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }

        return Publishers.MergeMany([
            resilientUpload(uploadDozyEvents(userID: userID)),
            resilientUpload(uploadEventCompletions(userID: userID)),
            resilientUpload(uploadWorkLogs(userID: userID)),
            resilientUpload(uploadEventDisplaySettings(userID: userID)),
            resilientUpload(uploadUserCategories(userID: userID))
        ])
        .collect()
        .flatMap { [weak self] _ -> AnyPublisher<Void, DozyError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return Publishers.MergeMany([
                self.downloadDozyEvents(userID: userID),
                self.downloadEventCompletions(userID: userID),
                self.downloadWorkLogs(userID: userID),
                self.downloadEventDisplaySettings(userID: userID),
                self.downloadUserCategories(userID: userID)
            ])
            .collect()
            .map { _ in }
            .eraseToAnyPublisher()
        }
        .handleEvents(receiveOutput: {
            // 동기화 성공 시각 기록 → 다음 앱 시작 시 쓰로틀 판단에 사용
            UserDefaults.standard.set(Date(), forKey: SyncService.lastSyncTimestampKey)
            Logger.sync.info("📅 동기화 타임스탬프 기록 완료")
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - Upload
    
    private func uploadDozyEvents(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let events = try self.modelContext.fetch(FetchDescriptor<DozyEvent>())
                    Logger.sync.info("⬆️ DozyEvents 업로드 시작 (\(events.count)건)")
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
                            memos: event.memos,
                            isCompleted: event.isCompleted,
                            priority: event.priority,
                            isPinned: event.isPinned,
                            category: event.category,
                            createdAt: event.createdAt,
                            updatedAt: event.updatedAt
                        )
                    }
                    guard !rows.isEmpty else { promise(.success(())); return }
                    try await supabase.from("dozy_events").upsert(rows).execute()
                    Logger.sync.info("✅ DozyEvents 업로드 완료")
                    promise(.success(()))
                } catch {
                    Logger.sync.error("❌ DozyEvents 업로드 실패: \(error.localizedDescription)")
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
                    Logger.sync.info("✅ EventCompletions 업로드 완료 (\(rows.count)건)")
                    promise(.success(()))
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
    
    private func uploadEventDisplaySettings(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let settings = try self.modelContext.fetch(FetchDescriptor<EventDisplaySettings>())
                    let rows = settings.map { s in
                        EventDisplaySettingsRow(
                            userID: userID,
                            eventID: s.eventID,
                            priority: s.priority,
                            isPinned: s.isPinned,
                            category: s.category,
                            updatedAt: Date()
                        )
                    }
                    guard !rows.isEmpty else { promise(.success(())); return }
                    try await supabase.from("event_display_settings")
                        .upsert(rows, onConflict: "user_id, event_id")
                        .execute()
                    Logger.sync.info("✅ EventDisplaySettings 업로드 완료 (\(rows.count)건)")
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func uploadUserCategories(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let cats = try self.modelContext.fetch(FetchDescriptor<UserCategory>())
                    let rows = cats.map { c in
                        UserCategoryRow(
                            id: c.id,
                            userID: userID,
                            name: c.name,
                            emoji: c.emoji,
                            colorHex: c.colorHex,
                            order: c.order,
                            updatedAt: c.updatedAt
                        )
                    }
                    guard !rows.isEmpty else { promise(.success(())); return }
                    // onConflict: "id" 로 먼저 시도. id가 없으면 새 행을 INSERT하는데,
                    // user_id+name 유니크 제약이 있으면 실패할 수 있으므로
                    // 외부 resilientUpload wrapper가 이 에러를 잡아서 다운로드를 보장한다.
                    try await supabase.from("user_categories").upsert(rows, onConflict: "id").execute()
                    Logger.sync.info("✅ UserCategories 업로드 완료 (\(rows.count)건)")
                    promise(.success(()))
                } catch {
                    Logger.sync.error("❌ UserCategories 업로드 실패: \(error.localizedDescription)")
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
                            notificationMinutesBefore: row.notificationMinutesBefore,
                            priority: row.priority,
                            isPinned: row.isPinned,
                            category: row.category
                        )
                        event.memos = row.memos
                        event.isCompleted = row.isCompleted
                        self.modelContext.insert(event)
                    }
                    try self.modelContext.save()
                    Logger.sync.info("⬇️ DozyEvents 다운로드 완료 (\(rows.count)건)")
                    promise(.success(()))
                } catch {
                    Logger.sync.error("❌ DozyEvents 다운로드 실패: \(error.localizedDescription)")
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

    private func downloadEventDisplaySettings(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let rows: [EventDisplaySettingsRow] = try await supabase
                        .from("event_display_settings")
                        .select()
                        .eq("user_id", value: userID)
                        .execute()
                        .value
                    let existing = try self.modelContext.fetch(FetchDescriptor<EventDisplaySettings>())
                    for row in rows {
                        if let local = existing.first(where: { $0.eventID == row.eventID }) {
                            local.priority = row.priority
                            local.isPinned = row.isPinned
                            local.category = row.category
                        } else {
                            self.modelContext.insert(
                                EventDisplaySettings(
                                    eventID: row.eventID,
                                    priority: row.priority,
                                    isPinned: row.isPinned,
                                    category: row.category
                                )
                            )
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
    
    private func downloadUserCategories(userID: String) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let rows: [UserCategoryRow] = try await supabase
                        .from("user_categories")
                        .select()
                        .eq("user_id", value: userID)
                        .execute()
                        .value
                    let existing = try self.modelContext.fetch(FetchDescriptor<UserCategory>())
                    for row in rows {
                        if let local = existing.first(where: { $0.id == row.id }) {
                            // 원격이 더 최신이면 덮어쓰기
                            if row.updatedAt > local.updatedAt {
                                local.name = row.name
                                local.emoji = row.emoji
                                local.colorHex = row.colorHex
                                local.order = row.order
                                local.updatedAt = row.updatedAt
                            }
                        } else {
                            // 이름 중복 방지: 같은 이름의 로컬 카테고리가 있으면 원격 데이터로 업데이트
                            if let duplicate = existing.first(where: { $0.name == row.name }) {
                                duplicate.id = row.id
                                duplicate.emoji = row.emoji
                                duplicate.colorHex = row.colorHex
                                duplicate.order = row.order
                                duplicate.updatedAt = row.updatedAt
                            } else {
                                let cat = UserCategory(name: row.name, emoji: row.emoji, colorHex: row.colorHex, order: row.order)
                                cat.id = row.id
                                cat.updatedAt = row.updatedAt
                                self.modelContext.insert(cat)
                            }
                        }
                    }
                    try self.modelContext.save()
                    Logger.sync.info("⬇️ UserCategories 다운로드 완료 (\(rows.count)건)")
                    promise(.success(()))
                } catch {
                    Logger.sync.error("❌ UserCategories 다운로드 실패: \(error.localizedDescription)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 로컬 SwiftData 전체 삭제 (탈퇴 시 호출)
    func clearAllLocalData() {
        let deletions: [() throws -> Void] = [
            { try self.modelContext.delete(model: WorkLog.self) },
            { try self.modelContext.delete(model: EventCompletion.self) },
            { try self.modelContext.delete(model: EventDisplaySettings.self) },
            { try self.modelContext.delete(model: UserCategory.self) },
            { try self.modelContext.delete(model: DozyEvent.self) }
        ]
        for deletion in deletions { try? deletion() }
        try? modelContext.save()
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
    let memos: [String]
    let isCompleted: Bool
    let priority: Int
    let isPinned: Bool
    let category: String
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct EventDisplaySettingsRow: Codable {
    let userID: String
    let eventID: String
    let priority: Int
    let isPinned: Bool
    let category: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case eventID = "event_id"
        case priority
        case isPinned = "is_pinned"
        case category
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

private struct UserCategoryRow: Codable {
    let id: String
    let userID: String
    let name: String
    let emoji: String
    let colorHex: String
    let order: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name, emoji
        case colorHex = "color_hex"
        case order
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
