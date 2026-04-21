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
    private let originalColorHex: String

    // Apple 시스템 팔레트 기반 12색 — 시각적으로 서로 명확히 구분되도록 엄선
    private let presetColors: [Color] = [
        Color(hex: "#FF3B30") ?? .red,      // Red
        Color(hex: "#FF9500") ?? .orange,   // Orange
        Color(hex: "#FFCC00") ?? .yellow,   // Yellow
        Color(hex: "#34C759") ?? .green,    // Green
        Color(hex: "#00C7BE") ?? .mint,     // Mint
        Color(hex: "#30B0C7") ?? .teal,     // Teal
        Color(hex: "#007AFF") ?? .blue,     // Blue
        Color(hex: "#5856D6") ?? .indigo,   // Indigo
        Color(hex: "#AF52DE") ?? .purple,   // Purple
        Color(hex: "#FF2D55") ?? .pink,     // Pink
        Color(hex: "#A2845E") ?? .brown,    // Brown
        Color(hex: "#8E8E93") ?? .gray      // Gray
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
        originalColorHex = category?.colorHex ?? "#8E8E93"
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
                        }
                        .buttonStyle(.plain)
                        TextField("카테고리 이름", text: $name)
                    }
                }

                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
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
            let oldColorHex = originalColorHex
            cat.name = trimmedName
            cat.emoji = emoji
            cat.colorHex = colorHex
            cat.updatedAt = Date()
            target = cat

            let nameChanged = oldName != trimmedName
            let colorChanged = oldColorHex != colorHex

            if nameChanged || colorChanged {
                for event in allDozyEvents where event.category == oldName {
                    if nameChanged { event.category = trimmedName }
                    if colorChanged { event.colorHex = colorHex }
                    event.updatedAt = Date()
                    affectedEvents.append(event)
                }
                if nameChanged {
                    for settings in allDisplaySettings where settings.category == oldName {
                        settings.category = trimmedName
                        affectedSettings.append(settings)
                    }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text(input.isEmpty ? selectedEmoji : input)
                    .font(.system(size: 72))
                    .frame(width: 120, height: 120)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))

                // 이모지 키보드를 자동으로 띄우는 숨김 입력 뷰
                EmojiKeyboardField(text: $input)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
            }
            .padding(.top, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - 이모지 키보드 강제 UIViewRepresentable

private struct EmojiKeyboardField: UIViewRepresentable {

    @Binding var text: String

    func makeUIView(context: Context) -> InternalEmojiTextField {
        let tf = InternalEmojiTextField()
        tf.delegate = context.coordinator
        DispatchQueue.main.async { tf.becomeFirstResponder() }
        return tf
    }

    func updateUIView(_ uiView: InternalEmojiTextField, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiKeyboardField
        init(_ parent: EmojiKeyboardField) { self.parent = parent }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            let newText = (current as NSString).replacingCharacters(in: range, with: string)
            if let emoji = newText.filter({ $0.isEmoji }).last {
                parent.text = String(emoji)
                textField.text = String(emoji)
            } else {
                parent.text = ""
                textField.text = ""
            }
            return false
        }
    }
}

private class InternalEmojiTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }
}
