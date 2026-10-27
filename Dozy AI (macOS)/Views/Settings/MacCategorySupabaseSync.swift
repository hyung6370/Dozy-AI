//
//  MacCategorySupabaseSync.swift
//  Dozy AI (macOS)
//
//  M4.8 — 카테고리/연관 이벤트의 Supabase 업서트·삭제 헬퍼.
//  MacCategoryEditSheet 와 MacCategoryManagementView 에서 공용 사용.
//

import Foundation
import Supabase

enum MacCategorySupabaseSync {

    static func upsert(_ cat: UserCategory) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let row = UserCategoryRow(
            id: cat.id,
            userID: userID,
            name: cat.name,
            emoji: cat.emoji,
            colorHex: cat.colorHex,
            order: cat.order,
            updatedAt: cat.updatedAt
        )
        try? await supabase.from("user_categories").upsert(row, onConflict: "id").execute()
    }

    static func upsertAll(_ cats: [UserCategory]) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let rows = cats.map {
            UserCategoryRow(
                id: $0.id,
                userID: userID,
                name: $0.name,
                emoji: $0.emoji,
                colorHex: $0.colorHex,
                order: $0.order,
                updatedAt: $0.updatedAt
            )
        }
        try? await supabase.from("user_categories").upsert(rows, onConflict: "id").execute()
    }

    static func delete(id: String) async {
        _ = try? await supabase.auth.session
        try? await supabase.from("user_categories").delete().eq("id", value: id).execute()
    }

    static func upsertEvents(_ events: [DozyEvent]) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let rows = events.map { e in
            DozyEventCategoryRow(
                id: e.id,
                userID: userID,
                title: e.title,
                startDate: e.startDate,
                endDate: e.endDate,
                isAllDay: e.isAllDay,
                location: e.location,
                notes: e.notes,
                colorHex: e.colorHex,
                recurrenceRule: e.recurrenceRule,
                recurrenceEndDate: e.recurrenceEndDate,
                notificationMinutesBefore: e.notificationMinutesBefore,
                memos: e.memos,
                isCompleted: e.isCompleted,
                priority: e.priority,
                isPinned: e.isPinned,
                category: e.category,
                sharedCalendarID: e.sharedCalendarID,
                createdAt: e.createdAt,
                updatedAt: e.updatedAt
            )
        }
        try? await supabase.from("dozy_events").upsert(rows, onConflict: "id").execute()
    }
}

// MARK: - DTO

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
        case name
        case emoji
        case colorHex = "color_hex"
        case order
        case updatedAt = "updated_at"
    }
}

private struct DozyEventCategoryRow: Codable {
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
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case isAllDay = "is_all_day"
        case location
        case notes
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
