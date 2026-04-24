//
//  MacEventDetailView.swift
//  Dozy AI (macOS)
//
//  iOS EventDetailView 기능 parity — 정보 행 / 메모 / 표시 설정(상단 고정·우선순위·카테고리)
//  / 반복 일정 삭제 옵션 / 파트너 태그 / 외부 미러 배너.
//  macOS 는 Apple/Google 네이티브 이벤트 경로가 없어 DozyEvent 전용.
//

import SwiftUI
import SwiftData

struct MacEventDetailView: View {
    let event: CalendarEvent
    let dozyEvent: DozyEvent?
    let currentUserID: String
    let partnerDisplayName: String?
    let onEdit: (DozyEvent) -> Void
    let onDelete: (DozyEvent) -> Void
    let onDeleteThisOnly: (DozyEvent, Date) -> Void
    let onDeleteFutureOccurrences: (DozyEvent, Date) -> Void
    let onSaveMemos: (DozyEvent) -> Void
    let onUpdateDisplaySettings: (CalendarEvent, Int, Bool, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]

    // Memo state
    @State private var memos: [String] = []
    @State private var memoText: String = ""
    @State private var editingMemoIndex: Int? = nil
    @State private var editingMemoText: String = ""
    @State private var showEditMemoAlert = false
    @State private var deletingMemoIndex: Int? = nil
    @State private var showDeleteMemoAlert = false

    // Display settings state
    @State private var displayPriority: Int = 0
    @State private var displayIsPinned: Bool = false
    @State private var displayCategory: String = "일반"
    @State private var originalPriority: Int = 0
    @State private var originalIsPinned: Bool = false
    @State private var originalCategory: String = "일반"

    // Delete dialogs
    @State private var showDeleteDialog = false
    @State private var showRecurringEditConfirm = false

    private var hasDisplayChanges: Bool {
        displayPriority != originalPriority ||
        displayIsPinned != originalIsPinned ||
        displayCategory != originalCategory
    }

    /// 공유 캘린더 이벤트 중 내가 생성자가 아닐 때는 편집 불가 (읽기 전용).
    private var canEditEvent: Bool {
        guard let dozyEvent else { return false }
        if dozyEvent.sharedCalendarID == nil { return true }
        guard let ownerID = dozyEvent.ownerID else { return true }
        return ownerID == currentUserID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    Divider().padding(.horizontal, 20).padding(.vertical, 6)
                    infoSection
                    if let dozy = dozyEvent {
                        memoSection(dozy)
                        dozyActionSection(dozy)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("일정 상세")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onUpdateDisplaySettings(event, displayPriority, displayIsPinned, displayCategory)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasDisplayChanges)
                }
            }
            .onAppear {
                memos = dozyEvent?.memos ?? []
                displayPriority = event.priority
                displayIsPinned = event.isPinned
                displayCategory = dozyEvent?.category ?? event.category
                originalPriority = displayPriority
                originalIsPinned = displayIsPinned
                originalCategory = displayCategory
            }
            .alert("메모 삭제", isPresented: $showDeleteMemoAlert) {
                Button("삭제", role: .destructive) {
                    if let index = deletingMemoIndex, index < memos.count, let dozy = dozyEvent {
                        memos.remove(at: index)
                        dozy.memos = memos
                        onSaveMemos(dozy)
                    }
                    deletingMemoIndex = nil
                }
                Button("취소", role: .cancel) { deletingMemoIndex = nil }
            } message: {
                Text("정말로 삭제하시겠습니까?")
            }
            .alert("메모 수정", isPresented: $showEditMemoAlert) {
                TextField("메모", text: $editingMemoText)
                Button("저장") {
                    if let index = editingMemoIndex, index < memos.count, let dozy = dozyEvent {
                        memos[index] = editingMemoText
                        dozy.memos = memos
                        onSaveMemos(dozy)
                    }
                    editingMemoIndex = nil
                }
                Button("취소", role: .cancel) { editingMemoIndex = nil }
            }
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 600)
    }

    // MARK: - Header

    private var headerSection: some View {
        let currentCategory = categories.first(where: { $0.name == displayCategory })
        let barColor: Color = {
            if let cat = currentCategory {
                return Color(hex: cat.colorHex) ?? .blue
            }
            return Color(hex: event.calendarColorHex) ?? .blue
        }()

        return HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor)
                .frame(width: 6, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let emoji = currentCategory?.emoji {
                        Text(emoji).font(.title3)
                    }
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    if event.isShared {
                        Label("공유 캘린더", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let partnerDisplayName, !partnerDisplayName.isEmpty {
                        Label(partnerDisplayName, systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Info rows

    private var infoSection: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "clock", label: "시간", value: event.timeRangeString)

            if let location = event.location, !location.isEmpty {
                divider
                DetailRow(icon: "mappin", label: "위치", value: location)
            }

            if let notes = event.notes, !notes.isEmpty {
                divider
                DetailRow(icon: "note.text", label: "설명", value: notes)
            }

            divider
            DetailRow(icon: "calendar", label: "캘린더", value: event.calendarName)

            if let dozyEvent, dozyEvent.recurrenceRule != "none" {
                divider
                DetailRow(icon: "repeat", label: "반복", value: recurrenceLabel(dozyEvent.recurrenceRule))
            }

            if let dozyEvent, dozyEvent.notificationMinutesBefore >= 0 {
                divider
                DetailRow(icon: "bell", label: "알림", value: notificationLabel(dozyEvent.notificationMinutesBefore))
            }
        }
        .padding(.vertical, 4)
    }

    private var divider: some View {
        Divider().padding(.leading, 56)
    }

    private func recurrenceLabel(_ rule: String) -> String {
        switch rule {
        case "daily":   return "매일"
        case "weekly":  return "매주"
        case "monthly": return "매월"
        case "yearly":  return "매년"
        default:        return "-"
        }
    }

    private func notificationLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0:    return "정시"
        case 5:    return "5분 전"
        case 10:   return "10분 전"
        case 15:   return "15분 전"
        case 30:   return "30분 전"
        case 60:   return "1시간 전"
        default:   return "\(minutes)분 전"
        }
    }

    // MARK: - Memo section

    private func memoSection(_ dozy: DozyEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.top, 10)

            Text("메모")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 6)

            ForEach(Array(memos.enumerated()), id: \.offset) { index, memo in
                HStack(alignment: .top, spacing: 8) {
                    Text("📝").font(.subheadline)
                    Text(memo)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                .contextMenu {
                    Button {
                        editingMemoIndex = index
                        editingMemoText = memo
                        showEditMemoAlert = true
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingMemoIndex = index
                        showDeleteMemoAlert = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("메모를 남겨보세요", text: $memoText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitMemo(dozy) }
                Button { submitMemo(dozy) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }

    private func submitMemo(_ dozy: DozyEvent) {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        memos.append(trimmed)
        dozy.memos = memos
        onSaveMemos(dozy)
        memoText = ""
    }

    // MARK: - Dozy action section

    private func dozyActionSection(_ dozy: DozyEvent) -> some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 16)

            if canEditEvent {
                editableDisplaySettings
                Text("공유 캘린더 이벤트는 파트너도 같이 볼 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                readOnlyDisplaySettings(for: dozy)
            }

            if canEditEvent {
                actionButtons(for: dozy)
            }
        }
    }

    private var editableDisplaySettings: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $displayIsPinned) {
                Label("상단 고정", systemImage: displayIsPinned ? "pin.fill" : "pin")
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 16)

            HStack {
                Label("우선순위", systemImage: "chart.bar")
                Spacer()
                Picker("", selection: $displayPriority) {
                    Text("없음").tag(0)
                    Text("높음 🔴").tag(1)
                    Text("중간 🟡").tag(2)
                    Text("낮음 🔵").tag(3)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.leading, 16)

            HStack {
                Label("카테고리", systemImage: "tag")
                Spacer()
                Picker("", selection: $displayCategory) {
                    ForEach(categories) { cat in
                        Text("\(cat.emoji) \(cat.name)").tag(cat.name)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 160)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func readOnlyDisplaySettings(for dozy: DozyEvent) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("상단 고정", systemImage: dozy.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dozy.isPinned ? "ON" : "OFF")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().padding(.leading, 16)

            HStack {
                Label("우선순위", systemImage: "chart.bar").foregroundStyle(.secondary)
                Spacer()
                Text(priorityLabel(dozy.priority))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            Divider().padding(.leading, 16)

            HStack {
                Label("카테고리", systemImage: "tag").foregroundStyle(.secondary)
                Spacer()
                Text(dozy.category.isEmpty ? "-" : dozy.category)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func priorityLabel(_ value: Int) -> String {
        switch value {
        case 1: return "높음 🔴"
        case 2: return "중간 🟡"
        case 3: return "낮음 🔵"
        default: return "없음"
        }
    }

    // MARK: - Edit / Delete buttons

    private func actionButtons(for dozy: DozyEvent) -> some View {
        VStack(spacing: 10) {
            Button {
                if dozy.recurrenceRule != "none" {
                    showRecurringEditConfirm = true
                } else {
                    dismiss()
                    onEdit(dozy)
                }
            } label: {
                Label("수정", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 20)
            .confirmationDialog("반복 일정 수정", isPresented: $showRecurringEditConfirm, titleVisibility: .visible) {
                Button("모든 반복 일정 수정") {
                    dismiss()
                    onEdit(dozy)
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("반복 일정의 모든 항목이 수정됩니다.")
            }

            Button(role: .destructive) {
                showDeleteDialog = true
            } label: {
                Label("삭제", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .confirmationDialog(
                dozy.recurrenceRule != "none" ? "반복 일정 삭제" : "일정 삭제",
                isPresented: $showDeleteDialog,
                titleVisibility: .visible
            ) {
                if dozy.recurrenceRule != "none" {
                    Button("이 일정만 삭제", role: .destructive) {
                        onDeleteThisOnly(dozy, event.startDate)
                        dismiss()
                    }
                    Button("이후 모든 일정 삭제", role: .destructive) {
                        onDeleteFutureOccurrences(dozy, event.startDate)
                        dismiss()
                    }
                    Button("모든 반복 일정 삭제", role: .destructive) {
                        onDelete(dozy)
                        dismiss()
                    }
                    Button("취소", role: .cancel) { }
                } else {
                    Button("삭제", role: .destructive) {
                        onDelete(dozy)
                        dismiss()
                    }
                    Button("취소", role: .cancel) { }
                }
            } message: {
                Text(dozy.recurrenceRule != "none"
                     ? "삭제할 범위를 선택해주세요."
                     : "정말로 삭제하시겠습니까?")
            }
        }
    }
}

// MARK: - DetailRow

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
