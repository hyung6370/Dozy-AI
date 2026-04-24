//
//  MacCategoryManagementView.swift
//  Dozy AI (macOS)
//
//  M4.8 — 사용자 카테고리 관리 시트. 목록 / 추가 / 수정 / 삭제.
//  카테고리 삭제 시 해당 카테고리를 쓰던 모든 이벤트는 기본 "일반" 으로 변경되고
//  Supabase 동기화된다.
//

import SwiftUI
import SwiftData

struct MacCategoryManagementView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @Query private var allDozyEvents: [DozyEvent]

    @State private var showAddSheet = false
    @State private var editingCategory: UserCategory? = nil
    @State private var deletingCategory: UserCategory? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { cat in
                    HStack(spacing: 14) {
                        Text(cat.emoji).font(.title2)
                        Text(cat.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Circle()
                            .fill(Color(hex: cat.colorHex) ?? .gray)
                            .frame(width: 16, height: 16)
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
                    .contextMenu {
                        Button {
                            editingCategory = cat
                        } label: {
                            Label("수정", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingCategory = cat
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("카테고리 관리")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                MacCategoryEditSheet()
            }
            .sheet(item: $editingCategory) { cat in
                MacCategoryEditSheet(category: cat)
            }
            .alert(
                "카테고리 삭제",
                isPresented: Binding(
                    get: { deletingCategory != nil },
                    set: { if !$0 { deletingCategory = nil } }
                )
            ) {
                Button("삭제", role: .destructive) {
                    performDelete()
                }
                Button("취소", role: .cancel) { deletingCategory = nil }
            } message: {
                Text("'\(deletingCategory?.name ?? "")'을(를) 삭제하시겠습니까?\n해당 카테고리의 일정은 '일반'으로 변경됩니다.")
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 420)
    }

    // MARK: - Delete

    private func performDelete() {
        guard let cat = deletingCategory else { return }
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
            await MacCategorySupabaseSync.delete(id: catID)
            if !affected.isEmpty {
                await MacCategorySupabaseSync.upsertEvents(affected)
            }
        }
        deletingCategory = nil
    }
}
