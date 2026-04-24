//
//  MacCategoryEditSheet.swift
//  Dozy AI (macOS)
//
//  M4.8 — 카테고리 추가/수정 시트. iOS CategoryEditSheet 의 기능 중
//  이름 / 이모지 입력 / 12색 프리셋 + ColorPicker 만 포함한 간소화 버전.
//  저장 시 SwiftData + Supabase user_categories 업서트.
//

import SwiftUI
import SwiftData
import Supabase

struct MacCategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @Query private var allDozyEvents: [DozyEvent]

    var category: UserCategory? = nil

    @State private var name: String
    @State private var emoji: String
    @State private var selectedColor: Color
    private let originalName: String
    private let originalColorHex: String

    private let presetColors: [Color] = [
        Color(hex: "#FF3B30") ?? .red,
        Color(hex: "#FF9500") ?? .orange,
        Color(hex: "#FFCC00") ?? .yellow,
        Color(hex: "#34C759") ?? .green,
        Color(hex: "#00C7BE") ?? .mint,
        Color(hex: "#30B0C7") ?? .teal,
        Color(hex: "#007AFF") ?? .blue,
        Color(hex: "#5856D6") ?? .indigo,
        Color(hex: "#AF52DE") ?? .purple,
        Color(hex: "#FF2D55") ?? .pink,
        Color(hex: "#A2845E") ?? .brown,
        Color(hex: "#8E8E93") ?? .gray
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
                    HStack(spacing: 10) {
                        TextField("📌", text: $emoji)
                            .frame(width: 44)
                            .multilineTextAlignment(.center)
                            .font(.title2)
                        TextField("카테고리 이름", text: $name)
                    }
                }

                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(presetColors.indices, id: \.self) { i in
                            let color = presetColors[i]
                            ZStack {
                                Circle().fill(color).frame(width: 32, height: 32)
                                if color.toHex() == selectedColor.toHex() {
                                    Image(systemName: "checkmark")
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { selectedColor = color }
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.vertical, 4)

                    ColorPicker("직접 선택", selection: $selectedColor, supportsOpacity: false)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "카테고리 수정" : "카테고리 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              emoji.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 460)
    }

    // MARK: - Save

    private func save() {
        let colorHex = selectedColor.toHex() ?? "#8E8E93"
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let target: UserCategory
        var affectedEvents: [DozyEvent] = []

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
                try? context.save()
            }
        } else {
            let maxOrder = categories.map { $0.order }.max() ?? -1
            let newCat = UserCategory(name: trimmedName, emoji: emoji, colorHex: colorHex, order: maxOrder + 1)
            context.insert(newCat)
            target = newCat
        }
        Task {
            await MacCategorySupabaseSync.upsert(target)
            if !affectedEvents.isEmpty {
                await MacCategorySupabaseSync.upsertEvents(affectedEvents)
            }
        }
    }
}
