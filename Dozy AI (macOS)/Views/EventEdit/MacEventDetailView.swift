//
//  MacEventDetailView.swift
//  Dozy AI (macOS)
//
//  M4.7 — 일정 상세 + 편집/삭제 액션. iOS EventDetailView 의 풀 기능 중
//  읽기 요약 + DozyEvent 액션만 포함한 간소화 버전. 외부 캘린더 연동은
//  macOS 지원 시점에 확장 예정.
//

import SwiftUI

struct MacEventDetailView: View {
    let event: CalendarEvent
    let dozyEvent: DozyEvent?
    let onEdit: (DozyEvent) -> Void
    let onDelete: (DozyEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                timeSection
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                }
                if let notes = event.notes, !notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("메모")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("일정 상세")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                if let dozyEvent {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("삭제", role: .destructive) {
                            showDeleteAlert = true
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("편집") {
                            onEdit(dozyEvent)
                        }
                    }
                }
            }
            .alert("일정 삭제", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    if let dozyEvent {
                        onDelete(dozyEvent)
                        dismiss()
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("\"\(event.title)\" 일정을 삭제하시겠습니까?")
            }
        }
        .frame(minWidth: 440, idealWidth: 520, minHeight: 360)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: event.calendarColorHex) ?? .blue)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if event.isShared {
                    Label("공유 캘린더", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var timeSection: some View {
        Label(event.timeRangeString, systemImage: "clock")
            .font(.subheadline)
    }
}
