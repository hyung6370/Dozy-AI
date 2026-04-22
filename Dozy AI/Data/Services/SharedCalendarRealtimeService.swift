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
            // 1) 기존 이벤트 초기 fetch (파트너가 이미 만들어둔 일정 동기화)
            await self.fetchAndSyncExistingEvents(calendarID: calendarID)
            // 2) 파트너 닉네임 캐시 갱신
            await self.fetchAndCachePartnerNickname(calendarID: calendarID)
            // 3) 실시간 변경 구독
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

    /// 앱이 포그라운드로 복귀했을 때 호출. 현재 감시 중인 모든 공유 캘린더에 대해
    /// 원격 상태와 로컬을 재동기화한다. `REPLICA IDENTITY DEFAULT`로 인해 더이상
    /// Realtime으로 오지 않는 DELETE 이벤트와 파트너 탈퇴를 이 경로로 커버한다.
    func resyncAllActive() {
        let calendarIDs = Array(channelTasks.keys)
        for calendarID in calendarIDs {
            Task { [weak self] in
                await self?.fetchAndSyncExistingEvents(calendarID: calendarID)
                await self?.checkPartnerMembership(calendarID: calendarID)
                await self?.fetchAndCachePartnerNickname(calendarID: calendarID)
            }
        }
    }

    // MARK: - 채널 실행

    /// INSERT/UPDATE 이벤트만 실시간 구독. DELETE는 `REPLICA IDENTITY DEFAULT` 상태에선
    /// Realtime으로 오지 않으므로, `fetchAndSyncExistingEvents`의 resync 경로에서 처리한다.
    /// 파트너 탈퇴 감지도 동일 — 포그라운드 복귀 시 `fetchMembers`로 확인한다.
    private func runChannel(_ channel: RealtimeChannelV2, calendarID: String) async {
        let eventsFilter = "shared_calendar_id=eq.\(calendarID)"

        let insertions = channel.postgresChange(
            InsertAction.self, schema: "public", table: "dozy_events", filter: eventsFilter)
        let updates = channel.postgresChange(
            UpdateAction.self, schema: "public", table: "dozy_events", filter: eventsFilter)

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

    // MARK: - Initial / Foreground Resync

    /// 원격 공유 이벤트 전체를 가져와 로컬과 맞춘다.
    /// 1) 원격에 있는 row는 upsert
    /// 2) 로컬에 있으나 원격에 없는 row는 삭제 (Realtime DELETE를 대체)
    private func fetchAndSyncExistingEvents(calendarID: String) async {
        do {
            let rows: [DozyEventDownloadRow] = try await supabase
                .from("dozy_events")
                .select()
                .eq("shared_calendar_id", value: calendarID)
                .execute()
                .value

            Logger.realtime.info("📥 \(calendarID) 초기 fetch: \(rows.count)개")

            let remoteIDs = Set(rows.map { $0.id })

            // (2) 로컬에만 있는 row 삭제 — 파트너가 공유 해제/자동 삭제한 row 정리.
            let calID = calendarID
            let localStale: [DozyEvent] = {
                let predicate = #Predicate<DozyEvent> { $0.sharedCalendarID == calID }
                let descriptor = FetchDescriptor<DozyEvent>(predicate: predicate)
                let local = (try? modelContext.fetch(descriptor)) ?? []
                return local.filter { !remoteIDs.contains($0.id) }
            }()
            if !localStale.isEmpty {
                for event in localStale { modelContext.delete(event) }
                try? modelContext.save()
                Logger.realtime.info("🗑 \(calendarID) 로컬 고아 삭제: \(localStale.count)개")
            }

            // (1) 원격 row upsert
            for row in rows {
                let sharedRow = SharedEventRow(
                    id: row.id, userID: row.userID, title: row.title,
                    startDate: row.startDate, endDate: row.endDate,
                    isAllDay: row.isAllDay, location: row.location, notes: row.notes,
                    colorHex: row.colorHex, recurrenceRule: row.recurrenceRule,
                    recurrenceEndDate: row.recurrenceEndDate,
                    notificationMinutesBefore: row.notificationMinutesBefore,
                    memos: row.memos, isCompleted: row.isCompleted,
                    priority: row.priority, isPinned: row.isPinned,
                    category: row.category, sharedCalendarID: row.sharedCalendarID,
                    externalSource: row.externalSource,
                    externalEventID: row.externalEventID,
                    externalLastSyncedAt: row.externalLastSyncedAt,
                    externalDeleted: row.externalDeleted
                )
                await upsertEvent(row: sharedRow, isUpdate: true)
            }
        } catch {
            Logger.realtime.error("⚠️ 초기 fetch 실패 (\(calendarID)): \(error.localizedDescription)")
        }
    }

    /// 파트너 탈퇴 감지. 멤버가 나 혼자만 남으면 partnerLeft 이벤트 발행.
    private func checkPartnerMembership(calendarID: String) async {
        struct Row: Decodable {
            let userID: String
            enum CodingKeys: String, CodingKey { case userID = "user_id" }
        }
        do {
            let rows: [Row] = try await supabase
                .from("shared_calendar_members")
                .select("user_id")
                .eq("shared_calendar_id", value: calendarID)
                .execute()
                .value
            if rows.count <= 1 {
                await MainActor.run { [weak self] in
                    self?.partnerLeft = calendarID
                }
                Logger.realtime.info("👋 파트너 탈퇴 감지(폴링): \(calendarID)")
            }
        } catch {
            Logger.realtime.error("⚠️ 멤버 체크 실패 (\(calendarID)): \(error.localizedDescription)")
        }
    }

    // MARK: - Partner Nickname Cache

    private func fetchAndCachePartnerNickname(calendarID: String) async {
        struct MemberRow: Decodable {
            let userID: String
            let nickname: String?
            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case nickname
            }
        }

        do {
            let rows: [MemberRow] = try await supabase
                .from("shared_calendar_members")
                .select("user_id, nickname")
                .eq("shared_calendar_id", value: calendarID)
                .execute()
                .value

            let userID = try await supabase.auth.session.user.id.uuidString.lowercased()
            let partner = rows.first { $0.userID.lowercased() != userID }
            ActiveSharedCalendarStore.shared.updatePartnerNickname(partner?.nickname, for: calendarID)
            Logger.realtime.info("👤 파트너 닉네임 캐시 갱신: \(calendarID) → \(partner?.nickname ?? "nil")")
        } catch {
            Logger.realtime.error("⚠️ 파트너 닉네임 fetch 실패: \(error.localizedDescription)")
        }
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
            event.externalSource = row.externalSource
            event.externalEventID = row.externalEventID
            event.externalLastSyncedAt = row.externalLastSyncedAt
            event.externalDeleted = row.externalDeleted
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
                sharedCalendarID: row.sharedCalendarID, ownerID: row.userID,
                externalSource: row.externalSource,
                externalEventID: row.externalEventID,
                externalLastSyncedAt: row.externalLastSyncedAt,
                externalDeleted: row.externalDeleted
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
        let externalSource: String? = {
            if case .string(let v) = record["external_source"] { return v }
            return nil
        }()
        let externalEventID: String? = {
            if case .string(let v) = record["external_event_id"] { return v }
            return nil
        }()
        let externalLastSyncedAt: Date? = {
            if case .string(let v) = record["external_last_synced_at"] { return parseDate(v) }
            return nil
        }()
        let externalDeleted: Bool = {
            if case .bool(let v) = record["external_deleted"] { return v }
            return false
        }()

        return SharedEventRow(
            id: id, userID: userID, title: title,
            startDate: startDate, endDate: endDate, isAllDay: isAllDay,
            location: location, notes: notes, colorHex: colorHex,
            recurrenceRule: recurrenceRule, recurrenceEndDate: recurrenceEndDate,
            notificationMinutesBefore: notificationMinutesBefore, memos: memos,
            isCompleted: isCompleted, priority: priority, isPinned: isPinned,
            category: category, sharedCalendarID: sharedCalendarID,
            externalSource: externalSource,
            externalEventID: externalEventID,
            externalLastSyncedAt: externalLastSyncedAt,
            externalDeleted: externalDeleted
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
    let externalSource: String?
    let externalEventID: String?
    let externalLastSyncedAt: Date?
    let externalDeleted: Bool
}

/// 초기 fetch용 DTO — Supabase에서 dozy_events 테이블을 select할 때 사용.
private struct DozyEventDownloadRow: Decodable {
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
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userID = try c.decode(String.self, forKey: .userID)
        title = try c.decode(String.self, forKey: .title)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        isAllDay = try c.decode(Bool.self, forKey: .isAllDay)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        recurrenceRule = try c.decode(String.self, forKey: .recurrenceRule)
        recurrenceEndDate = try c.decodeIfPresent(Date.self, forKey: .recurrenceEndDate)
        notificationMinutesBefore = try c.decode(Int.self, forKey: .notificationMinutesBefore)
        memos = try c.decodeIfPresent([String].self, forKey: .memos) ?? []
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        priority = try c.decode(Int.self, forKey: .priority)
        isPinned = try c.decode(Bool.self, forKey: .isPinned)
        category = try c.decode(String.self, forKey: .category)
        sharedCalendarID = try c.decodeIfPresent(String.self, forKey: .sharedCalendarID)
        externalSource = try c.decodeIfPresent(String.self, forKey: .externalSource)
        externalEventID = try c.decodeIfPresent(String.self, forKey: .externalEventID)
        externalLastSyncedAt = try c.decodeIfPresent(Date.self, forKey: .externalLastSyncedAt)
        externalDeleted = try c.decodeIfPresent(Bool.self, forKey: .externalDeleted) ?? false
    }
}

private extension Logger {
    static let realtime = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dozy", category: "Realtime")
}
