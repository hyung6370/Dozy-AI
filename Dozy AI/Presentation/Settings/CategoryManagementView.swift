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
                    let catID = cat.id
                    context.delete(cat)
                    Task { await deleteFromSupabase(id: catID) }
                }
                deletingCategory = nil
            }
            Button("취소", role: .cancel) { deletingCategory = nil }
        } message: {
            Text("'\(deletingCategory?.name ?? "")'을(를) 삭제하시겠습니까?\n해당 카테고리로 등록된 일정은 유지됩니다.")
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
