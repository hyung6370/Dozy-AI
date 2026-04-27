//
//  MacEventDetailView.swift
//  Dozy AI (macOS)
//
//  iOS EventDetailView 기능 parity — 모든 필드 인라인 편집 가능.
//  제목/시간/위치/설명/반복/알림 + 표시 설정(상단 고정·우선순위·카테고리) + 메모 + 삭제.
//  macOS 는 Apple/Google 네이티브 이벤트 경로가 없어 DozyEvent 전용.
//

import SwiftUI
import SwiftData

struct MacEventDetailView: View {
    let event: CalendarEvent
    let dozyEvent: DozyEvent?
    let currentUserID: String
    let partnerDisplayName: String?
    let onDelete: (DozyEvent) -> Void
    let onDeleteThisOnly: (DozyEvent, Date) -> Void
    let onDeleteFutureOccurrences: (DozyEvent, Date) -> Void
    let onSaveMemos: (DozyEvent) -> Void
    let onSaveEvent: (DozyEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @StateObject private var editVM: EventEditViewModel

    // Memo state
    @State private var memos: [String] = []
    @State private var memoText: String = ""
    @State private var editingMemoIndex: Int? = nil
    @State private var editingMemoText: String = ""
    @State private var showEditMemoAlert = false
    @State private var deletingMemoIndex: Int? = nil
    @State private var showDeleteMemoAlert = false

    // Dialogs
    @State private var showDeleteDialog = false
    @State private var showRecurringSaveConfirm = false

    init(
        event: CalendarEvent,
        dozyEvent: DozyEvent?,
        currentUserID: String,
        partnerDisplayName: String?,
        onDelete: @escaping (DozyEvent) -> Void,
        onDeleteThisOnly: @escaping (DozyEvent, Date) -> Void,
        onDeleteFutureOccurrences: @escaping (DozyEvent, Date) -> Void,
        onSaveMemos: @escaping (DozyEvent) -> Void,
        onSaveEvent: @escaping (DozyEvent) -> Void
    ) {
        self.event = event
        self.dozyEvent = dozyEvent
        self.currentUserID = currentUserID
        self.partnerDisplayName = partnerDisplayName
        self.onDelete = onDelete
        self.onDeleteThisOnly = onDeleteThisOnly
        self.onDeleteFutureOccurrences = onDeleteFutureOccurrences
        self.onSaveMemos = onSaveMemos
        self.onSaveEvent = onSaveEvent
        _editVM = StateObject(wrappedValue: EventEditViewModel(
            eventToEdit: dozyEvent,
            selectedDate: event.startDate,
            sharedCalendars: [],
            onSave: onSaveEvent
        ))
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
                        displaySettingsSection
                        if canEditEvent {
                            deleteSection(dozy)
                        }
                    }
                }
                .padding(.vertical, 8)
                .disabled(!canEditEvent && dozyEvent != nil)
            }
            .navigationTitle("일정 상세")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { commitSave() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!editVM.isSavable || !canEditEvent)
                }
            }
            .onAppear {
                memos = dozyEvent?.memos ?? []
                if let cat = categories.first(where: { $0.name == editVM.category }) {
                    editVM.selectedColor = Color(hex: cat.colorHex) ?? editVM.selectedColor
                }
            }
            .onChange(of: editVM.category) { _, newName in
                if let cat = categories.first(where: { $0.name == newName }) {
                    editVM.selectedColor = Color(hex: cat.colorHex) ?? editVM.selectedColor
                }
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
            .confirmationDialog(
                "반복 일정 수정",
                isPresented: $showRecurringSaveConfirm,
                titleVisibility: .visible
            ) {
                Button("모든 반복 일정 수정") {
                    editVM.save()
                    dismiss()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("반복 일정의 모든 항목이 수정됩니다.")
            }
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 600)
    }

    private func commitSave() {
        if let dozy = dozyEvent, dozy.recurrenceRule != "none" {
            showRecurringSaveConfirm = true
        } else {
            editVM.save()
            dismiss()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        let currentCategory = categories.first(where: { $0.name == editVM.category })
        let barColor: Color = {
            if let cat = currentCategory {
                return Color(hex: cat.colorHex) ?? .blue
            }
            return editVM.selectedColor
        }()
        let hasTags = event.isShared || (partnerDisplayName.map { !$0.isEmpty } ?? false)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: 6)

                if let emoji = currentCategory?.emoji {
                    Text(emoji).font(.title3)
                }
                TextField("제목", text: $editVM.title)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .fixedSize(horizontal: false, vertical: true)

            if hasTags {
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
                .padding(.leading, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Info rows (editable)

    private var infoSection: some View {
        VStack(spacing: 0) {
            timeRows

            divider
            EditRow(icon: "mappin", label: "위치") {
                TextField("장소 (선택)", text: $editVM.location)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
            }

            divider
            EditRow(icon: "note.text", label: "설명") {
                TextField("메모 (선택)", text: $editVM.notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .lineLimit(1...5)
            }

            divider
            EditRow(icon: "calendar", label: "캘린더") {
                Text(event.calendarName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            divider
            EditRow(icon: "repeat", label: "반복") {
                Picker("", selection: $editVM.recurrenceRule) {
                    Text("없음").tag("none")
                    Text("매일").tag("daily")
                    Text("매주").tag("weekly")
                    Text("매월").tag("monthly")
                    Text("매년").tag("yearly")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 180, alignment: .leading)
            }

            if editVM.recurrenceRule != "none" {
                divider
                EditRow(icon: "calendar.badge.clock", label: "종료일") {
                    DatePicker("", selection: $editVM.recurrenceEndDate, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, .koreanForce24h)
                }
            }

            divider
            EditRow(icon: "bell", label: "알림") {
                Picker("", selection: $editVM.notificationMinutesBefore) {
                    Text("없음").tag(-1)
                    Text("정시").tag(0)
                    Text("5분 전").tag(5)
                    Text("10분 전").tag(10)
                    Text("15분 전").tag(15)
                    Text("30분 전").tag(30)
                    Text("1시간 전").tag(60)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 180, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    private var timeRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            EditRow(icon: "clock", label: "시간") {
                Toggle("종일", isOn: $editVM.isAllDay)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            timeSubRow(
                label: "시작",
                date: $editVM.startDate,
                components: editVM.isAllDay ? .date : [.date, .hourAndMinute],
                lowerBound: nil
            )

            if !editVM.isAllDay {
                timeSubRow(
                    label: "종료",
                    date: $editVM.endDate,
                    components: [.date, .hourAndMinute],
                    lowerBound: editVM.startDate
                )
            }
        }
    }

    @ViewBuilder
    private func timeSubRow(
        label: String,
        date: Binding<Date>,
        components: DatePickerComponents,
        lowerBound: Date?
    ) -> some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 22)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            if let lowerBound {
                DatePicker("", selection: date, in: lowerBound..., displayedComponents: components)
                    .labelsHidden()
                    .environment(\.locale, .koreanForce24h)
            } else {
                DatePicker("", selection: date, displayedComponents: components)
                    .labelsHidden()
                    .environment(\.locale, .koreanForce24h)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
    }

    private var divider: some View {
        Divider().padding(.leading, 56)
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

    // MARK: - Display settings

    private var displaySettingsSection: some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 16)

            VStack(spacing: 0) {
                settingsRow {
                    Label("상단 고정", systemImage: editVM.isPinned ? "pin.fill" : "pin")
                } trailing: {
                    Toggle("", isOn: $editVM.isPinned)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider().padding(.leading, 16)

                settingsRow {
                    Label("우선순위", systemImage: "chart.bar")
                } trailing: {
                    Picker("", selection: $editVM.priority) {
                        Text("없음").tag(0)
                        Text("높음 🔴").tag(1)
                        Text("중간 🟡").tag(2)
                        Text("낮음 🔵").tag(3)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 160, alignment: .trailing)
                }

                Divider().padding(.leading, 16)

                settingsRow {
                    Label("카테고리", systemImage: "tag")
                } trailing: {
                    Picker("", selection: $editVM.category) {
                        ForEach(categories) { cat in
                            Text("\(cat.emoji) \(cat.name)").tag(cat.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 160, alignment: .trailing)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            if event.isShared {
                Text("공유 캘린더 이벤트는 파트너도 같이 볼 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    private func settingsRow<L: View, T: View>(
        @ViewBuilder label: () -> L,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack(spacing: 12) {
            label()
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Delete button

    private func deleteSection(_ dozy: DozyEvent) -> some View {
        Button(role: .destructive) {
            showDeleteDialog = true
        } label: {
            Label("삭제", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 20)
        .padding(.top, 16)
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

// MARK: - EditRow

private struct EditRow<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
