//
//  CategoryEditSheet.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/11/26.
//

import SwiftUI
import SwiftData
import Supabase

struct CategoryEditSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @Query private var allDozyEvents: [DozyEvent]
    @Query private var allDisplaySettings: [EventDisplaySettings]

    var category: UserCategory? = nil

    @State private var name: String
    @State private var emoji: String
    @State private var selectedColor: Color
    @State private var showEmojiPicker = false
    private let originalName: String

    private let presetColors: [Color] = [
        .blue, .purple, .orange, .green, .teal, .pink,
        .red, .indigo, .cyan, .yellow, .gray,
        Color(hex: "#FF9500") ?? .orange,
        Color(hex: "#34C759") ?? .green,
        Color(hex: "#AF52DE") ?? .purple
    ]

    init(category: UserCategory? = nil) {
        self.category = category
        let n = category?.name ?? ""
        let e = category?.emoji ?? "📌"
        let c = Color(hex: category?.colorHex ?? "#8E8E93") ?? .gray
        _name = State(initialValue: n)
        _emoji = State(initialValue: e)
        _selectedColor = State(initialValue: c)
        originalName = n
    }

    var isEditing: Bool { category != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    HStack {
                        Button {
                            showEmojiPicker = true
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .padding(6)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        TextField("카테고리 이름", text: $name)
                    }
                }

                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(presetColors.indices, id: \.self) { i in
                            let color = presetColors[i]
                            ZStack {
                                Circle().fill(color).frame(width: 36, height: 36)
                                if color.toHex() == selectedColor.toHex() {
                                    Image(systemName: "checkmark")
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { selectedColor = color }
                        }
                    }
                    .padding(.vertical, 4)

                    ColorPicker("직접 선택", selection: $selectedColor, supportsOpacity: false)
                }
            }
            .navigationTitle(isEditing ? "카테고리 수정" : "카테고리 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $emoji)
            }
        }
    }

    private func save() {
        let colorHex = selectedColor.toHex() ?? "#8E8E93"
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let target: UserCategory
        var affectedEvents: [DozyEvent] = []
        var affectedSettings: [EventDisplaySettings] = []
        if let cat = category {
            let oldName = originalName
            cat.name = trimmedName
            cat.emoji = emoji
            cat.colorHex = colorHex
            cat.updatedAt = Date()
            target = cat
            // 이름이 바뀐 경우 해당 카테고리를 사용하는 모든 레코드 업데이트
            if oldName != trimmedName {
                for event in allDozyEvents where event.category == oldName {
                    event.category = trimmedName
                    affectedEvents.append(event)
                }
                for settings in allDisplaySettings where settings.category == oldName {
                    settings.category = trimmedName
                    affectedSettings.append(settings)
                }
                try? context.save()
            }
        } else {
            let maxOrder = categories.map { $0.order }.max() ?? -1
            let newCat = UserCategory(name: trimmedName, emoji: emoji, colorHex: colorHex, order: maxOrder + 1)
            context.insert(newCat)
            target = newCat
        }
        Task {
            await upsertToSupabase(target)
            if !affectedEvents.isEmpty {
                await upsertEventsToSupabase(affectedEvents)
            }
            if !affectedSettings.isEmpty {
                await upsertDisplaySettingsToSupabase(affectedSettings)
            }
        }
    }

    private func upsertToSupabase(_ cat: UserCategory) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let row = UserCategoryRow(
            id: cat.id, userID: userID,
            name: cat.name, emoji: cat.emoji,
            colorHex: cat.colorHex, order: cat.order,
            updatedAt: cat.updatedAt
        )
        try? await supabase.from("user_categories").upsert(row, onConflict: "id").execute()
    }

    private func upsertDisplaySettingsToSupabase(_ settings: [EventDisplaySettings]) async {
        guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
        let rows = settings.map { s in
            DisplaySettingsRow(userID: userID, eventID: s.eventID,
                               priority: s.priority, isPinned: s.isPinned,
                               category: s.category, updatedAt: Date())
        }
        try? await supabase.from("event_display_settings").upsert(rows, onConflict: "user_id, event_id").execute()
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

// MARK: - Supabase DTOs

private struct DisplaySettingsRow: Codable {
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

// MARK: - 이모지 피커

private struct EmojiPickerSheet: View {

    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("이모지 키보드(🌐)로\n원하는 이모지를 선택하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(input.isEmpty ? selectedEmoji : input)
                    .font(.system(size: 72))
                    .frame(width: 120, height: 120)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                    .onTapGesture { isFocused = true }

                // 이모지 입력을 받는 숨김 TextField
                TextField("", text: $input)
                    .focused($isFocused)
                    .onChange(of: input) { _, new in
                        if let emoji = new.filter({ $0.isEmoji }).last {
                            input = String(emoji)
                        } else {
                            input = ""
                        }
                    }
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
            }
            .padding(.top, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { isFocused = true }
            .navigationTitle("이모지 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        if !input.isEmpty { selectedEmoji = input }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }
}
