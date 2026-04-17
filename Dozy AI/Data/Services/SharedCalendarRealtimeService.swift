//
//  SharedCalendarRealtimeService.swift
//  Dozy AI
//
//  공유 캘린더의 실시간 이벤트를 구독합니다.
//  - dozy_events: 파트너가 만든/수정한/삭제한 공유 일정 반영
//  - shared_calendar_members: 파트너 탈퇴 감지
//

import Foundation
import Combine
import SwiftData
import Supabase
import OSLog

@MainActor
final class SharedCalendarRealtimeService: ObservableObject {

    private let modelContext: ModelContext

    /// UI에서 파트너 탈퇴 시 알림 표시용
    @Published var partnerLeft: String? = nil   // calendarID

    private var channelTasks: [String: Task<Void, Never>] = [:]
    private var activeChannels: [String: RealtimeChannelV2] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - 공개 인터페이스

    func startWatching(calendarID: String) {
        guard channelTasks[calendarID] == nil else { return }
        Logger.realtime.info("📡 Realtime 구독 시작: \(calendarID)")

        let channel = supabase.channel("shared-\(calendarID)")
        activeChannels[calendarID] = channel

        channelTasks[calendarID] = Task { [weak self] in
            guard let self else { return }
            await self.runChannel(channel, calendarID: calendarID)
        }
    }

    func stopWatching(calendarID: String) {
        channelTasks[calendarID]?.cancel()
        channelTasks.removeValue(forKey: calendarID)
        if let ch = activeChannels.removeValue(forKey: calendarID) {
            Task { await ch.unsubscribe() }
        }
        Logger.realtime.info("🔌 Realtime 구독 해제: \(calendarID)")
    }

    func stopAll() {
        for key in channelTasks.keys { stopWatching(calendarID: key) }
    }

    // MARK: - 채널 실행

    private func runChannel(_ channel: RealtimeChannelV2, calendarID: String) async {
        let eventsFilter = "shared_calendar_id=eq.\(calendarID)"

        let insertions = channel.postgresChange(
            InsertAction.self, schema: "public", table: "dozy_events", filter: eventsFilter)
        let updates = channel.postgresChange(
            UpdateAction.self, schema: "public", table: "dozy_events", filter: eventsFilter)
        let deletions = channel.postgresChange(
            DeleteAction.self, schema: "public", table: "dozy_events", filter: eventsFilter)
        let memberDeletions = channel.postgresChange(
            DeleteAction.self, schema: "public", table: "shared_calendar_members",
            filter: "shared_calendar_id=eq.\(calendarID)")

        await channel.subscribe()
        Logger.realtime.info("✅ 채널 구독 완료: \(calendarID)")

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await action in insertions {
                    await self?.handleInsert(action)
                }
            }
            group.addTask { [weak self] in
                for await action in updates {
                    await self?.handleUpdate(action)
                }
            }
            group.addTask { [weak self] in
                for await action in deletions {
                    await self?.handleDelete(action)
                }
            }
            group.addTask { [weak self] in
                for await _ in memberDeletions {
                    await MainActor.run { self?.partnerLeft = calendarID }
                    Logger.realtime.info("👋 파트너 탈퇴 감지: \(calendarID)")
                }
            }
        }
    }

    // MARK: - INSERT

    private func handleInsert(_ action: InsertAction) async {
        guard let row = decode(record: action.record) else { return }
        await upsertEvent(row: row, isUpdate: false)
    }

    // MARK: - UPDATE

    private func handleUpdate(_ action: UpdateAction) async {
        guard let row = decode(record: action.record) else { return }
        await upsertEvent(row: row, isUpdate: true)
    }

    // MARK: - DELETE

    private func handleDelete(_ action: DeleteAction) async {
        guard case .string(let deletedID) = action.oldRecord["id"] else { return }
        let results = try? modelContext.fetch(
            FetchDescriptor<DozyEvent>(predicate: #Predicate { $0.id == deletedID }))
        guard let event = results?.first else { return }
        modelContext.delete(event)
        try? modelContext.save()
        Logger.realtime.info("🗑 공유 이벤트 DELETE: \(deletedID)")
    }

    // MARK: - Shared upsert logic

    private func upsertEvent(row: SharedEventRow, isUpdate: Bool) async {
        let rowID = row.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<DozyEvent>(predicate: #Predicate { $0.id == rowID }))

        if let event = existing?.first {
            guard isUpdate, event.ownerID == row.userID else { return }
            event.title = row.title
            event.startDate = row.startDate
            event.endDate = row.endDate
            event.isAllDay = row.isAllDay
            event.location = row.location
            event.notes = row.notes
            event.colorHex = row.colorHex
            event.recurrenceRule = row.recurrenceRule
            event.recurrenceEndDate = row.recurrenceEndDate
            event.notificationMinutesBefore = row.notificationMinutesBefore
            event.memos = row.memos
            event.isCompleted = row.isCompleted
            event.priority = row.priority
            event.isPinned = row.isPinned
            event.category = row.category
            try? modelContext.save()
            Logger.realtime.info("✏️ 공유 이벤트 UPDATE: \(row.title)")
        } else {
            let event = DozyEvent(
                id: row.id, title: row.title,
                startDate: row.startDate, endDate: row.endDate,
                isAllDay: row.isAllDay, location: row.location, notes: row.notes,
                colorHex: row.colorHex, recurrenceRule: row.recurrenceRule,
                recurrenceEndDate: row.recurrenceEndDate,
                notificationMinutesBefore: row.notificationMinutesBefore,
                priority: row.priority, isPinned: row.isPinned, category: row.category,
                sharedCalendarID: row.sharedCalendarID, ownerID: row.userID
            )
            event.memos = row.memos
            event.isCompleted = row.isCompleted
            modelContext.insert(event)
            try? modelContext.save()
            Logger.realtime.info("➕ 공유 이벤트 INSERT: \(row.title)")
        }
    }

    // MARK: - Decode helper

    private func decode(record: [String: AnyJSON]) -> SharedEventRow? {
        guard
            case .string(let id)            = record["id"],
            case .string(let userID)        = record["user_id"],
            case .string(let title)         = record["title"],
            case .string(let startStr)      = record["start_date"],
            case .string(let endStr)        = record["end_date"],
            let startDate = parseDate(startStr),
            let endDate   = parseDate(endStr)
        else { return nil }

        let isAllDay: Bool = {
            if case .bool(let v) = record["is_all_day"] { return v }
            return false
        }()
        let location: String? = {
            if case .string(let v) = record["location"] { return v }
            return nil
        }()
        let notes: String? = {
            if case .string(let v) = record["notes"] { return v }
            return nil
        }()
        let colorHex: String = {
            if case .string(let v) = record["color_hex"] { return v }
            return "#4A90E2"
        }()
        let recurrenceRule: String = {
            if case .string(let v) = record["recurrence_rule"] { return v }
            return "none"
        }()
        let recurrenceEndDate: Date? = {
            if case .string(let v) = record["recurrence_end_date"] { return parseDate(v) }
            return nil
        }()
        let notificationMinutesBefore: Int = {
            if case .integer(let v) = record["notification_minutes_before"] { return v }
            return -1
        }()
        let memos: [String] = {
            if case .array(let arr) = record["memos"] {
                return arr.compactMap { if case .string(let s) = $0 { return s }; return nil }
            }
            return []
        }()
        let isCompleted: Bool = {
            if case .bool(let v) = record["is_completed"] { return v }
            return false
        }()
        let priority: Int = {
            if case .integer(let v) = record["priority"] { return v }
            return 0
        }()
        let isPinned: Bool = {
            if case .bool(let v) = record["is_pinned"] { return v }
            return false
        }()
        let category: String = {
            if case .string(let v) = record["category"] { return v }
            return "일반"
        }()
        let sharedCalendarID: String? = {
            if case .string(let v) = record["shared_calendar_id"] { return v }
            return nil
        }()

        return SharedEventRow(
            id: id, userID: userID, title: title,
            startDate: startDate, endDate: endDate, isAllDay: isAllDay,
            location: location, notes: notes, colorHex: colorHex,
            recurrenceRule: recurrenceRule, recurrenceEndDate: recurrenceEndDate,
            notificationMinutesBefore: notificationMinutesBefore, memos: memos,
            isCompleted: isCompleted, priority: priority, isPinned: isPinned,
            category: category, sharedCalendarID: sharedCalendarID
        )
    }

    private func parseDate(_ string: String) -> Date? {
        // Supabase returns ISO8601 with or without fractional seconds
        let formatters: [ISO8601DateFormatter] = [
            {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
            {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
        ]
        for f in formatters {
            if let date = f.date(from: string) { return date }
        }
        return nil
    }
}

// MARK: - Internal DTO

private struct SharedEventRow {
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
}

private extension Logger {
    static let realtime = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dozy", category: "Realtime")
}
