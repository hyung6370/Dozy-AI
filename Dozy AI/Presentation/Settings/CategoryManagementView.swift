//
//  CategoryManagementView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/11/26.
//

import SwiftUI
import SwiftData
import Supabase

struct CategoryManagementView: View {

    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @Query private var allDozyEvents: [DozyEvent]
    @Environment(\.modelContext) private var context
    @State private var showAddSheet = false
    @State private var editingCategory: UserCategory? = nil
    @State private var deletingCategory: UserCategory? = nil

    var body: some View {
        List {
            ForEach(categories) { cat in
                HStack(spacing: 14) {
                    Text(cat.emoji).font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cat.name).font(.subheadline).fontWeight(.medium)
                    }
                    Spacer()
                    Circle()
                        .fill(Color(hex: cat.colorHex) ?? .gray)
                        .frame(width: 20, height: 20)
                }
                .contentShape(Rectangle())
                .onTapGesture { editingCategory = cat }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deletingCategory = cat
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: move)
        }
        .navigationTitle("카테고리 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryEditSheet()
        }
        .sheet(item: $editingCategory) { cat in
            CategoryEditSheet(category: cat)
        }
        .alert("카테고리 삭제", isPresented: Binding(
            get: { deletingCategory != nil },
            set: { if !$0 { deletingCategory = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let cat = deletingCategory {
                    let catName = cat.name
                    let catID = cat.id
                    var affected: [DozyEvent] = []
                    for event in allDozyEvents where event.category == catName {
                        event.category = UserCategory.defaultName
                        event.updatedAt = Date()
                        affected.append(event)
                    }
                    context.delete(cat)
                    try? context.save()
                    Task {
                        await deleteFromSupabase(id: catID)
                        if !affected.isEmpty { await upsertEventsToSupabase(affected) }
                    }
                }
                deletingCategory = nil
            }
            Button("취소", role: .cancel) { deletingCategory = nil }
        } message: {
            Text("'\(deletingCategory?.name ?? "")'을(를) 삭제하시겠습니까?\n해당 카테고리의 일정은 '일반'으로 변경됩니다.")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (i, cat) in reordered.enumerated() {
            cat.order = i
            cat.updatedAt = Date()
        }
        Task { await upsertAllToSupabase(reordered) }
    }

    private func deleteFromSupabase(id: String) async {
        guard (try? await supabase.auth.session) != nil else { return }
        try? await supabase.from("user_categories").delete().eq("id", value: id).execute()
    }

    private func upsertAllToSupabase(_ cats: [UserCategory]) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let rows = cats.map { UserCategoryRow(id: $0.id, userID: userID, name: $0.name, emoji: $0.emoji, colorHex: $0.colorHex, order: $0.order, updatedAt: $0.updatedAt) }
        try? await supabase.from("user_categories").upsert(rows, onConflict: "id").execute()
    }

    private func upsertEventsToSupabase(_ events: [DozyEvent]) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let rows = events.map { e in
            DozyEventRow(
                id: e.id, userID: userID,
                title: e.title, startDate: e.startDate, endDate: e.endDate,
                isAllDay: e.isAllDay, location: e.location, notes: e.notes,
                colorHex: e.colorHex, recurrenceRule: e.recurrenceRule,
                recurrenceEndDate: e.recurrenceEndDate,
                notificationMinutesBefore: e.notificationMinutesBefore,
                memos: e.memos, isCompleted: e.isCompleted,
                priority: e.priority, isPinned: e.isPinned,
                category: e.category,
                sharedCalendarID: e.sharedCalendarID,
                createdAt: e.createdAt, updatedAt: e.updatedAt
            )
        }
        try? await supabase.from("dozy_events").upsert(rows, onConflict: "id").execute()
    }
}

// MARK: - Supabase Event DTO

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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Supabase DTO

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
