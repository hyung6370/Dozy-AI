//
//  EventDetailView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import SwiftUI
import SwiftData

struct EventDetailView: View {
    
    let event: CalendarEvent
    let dozyEvent: DozyEvent?
    let onEdit: ((DozyEvent) -> Void)?
    let onDelete: ((DozyEvent) -> Void)?
    let onDeleteThisOnly: ((DozyEvent, Date) -> Void)?
    let onDeleteFutureEvents: ((DozyEvent, Date) -> Void)?
    let onEditCalendar: ((CalendarEvent) -> Void)?
    let onDeleteCalendar: ((CalendarEvent) -> Void)?
    let onSaveMemos: ((DozyEvent) -> Void)?
    let onUpdateDisplaySettings: ((CalendarEvent, Int, Bool, String?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @Query private var allDisplaySettings: [EventDisplaySettings]
    @State private var showCalendarDeleteConfirm = false
    @State private var showDozyDeleteConfirm = false
    @State private var memoText = ""
    @State private var editingMemoIndex: Int? = nil
    @State private var editingMemoText = ""
    @State private var showEditMemoAlert = false
    @State private var deletingMemoIndex: Int? = nil
    @State private var showDeleteMemoAlert = false
    @State private var memos: [String] = []
    @State private var displayPriority: Int = 0
    @State private var displayIsPinned: Bool = false
    @State private var displayCategory: String = UserCategory.defaultName
    @State private var originalPriority: Int = 0
    @State private var originalIsPinned: Bool = false
    @State private var originalCategory: String = UserCategory.defaultName
    @State private var showRecurringEditConfirm = false

    private var hasChanges: Bool {
        displayPriority != originalPriority
            || displayIsPinned != originalIsPinned
            || displayCategory != originalCategory
    }

    /// 파트너가 생성한 공유 캘린더 이벤트인지 여부.
    /// - 개인 이벤트(sharedCalendarID == nil): 항상 편집 가능
    /// - 공유 이벤트: ownerID와 현재 사용자 ID 일치 여부로 판단
    /// - ownerID가 nil인 레거시 이벤트: 편집 가능하게 처리 (마이그레이션 전 데이터)
    private var canEditEvent: Bool {
        guard let dozyEvent else { return true }
        if dozyEvent.sharedCalendarID == nil { return true }
        guard let ownerID = dozyEvent.ownerID else { return true }
        return ownerID == (authViewModel.currentUser?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    Divider().padding(.horizontal)
                    infoSection
                    if let dozyEvent {
                        memoSection(dozyEvent)
                        dozyActionSection(dozyEvent)
                    } else if event.source == .apple || event.source == .google {
                        calendarActionSection
                    }
                }
            }
            .onAppear {
                memos = dozyEvent?.memos ?? []
                displayPriority = event.priority
                displayIsPinned = event.isPinned
                // DozyEvent는 @Model 참조 타입 → 항상 최신 category 반영
                // Apple/Google 이벤트는 EventDisplaySettings에서 직접 조회
                if let dozyEvent {
                    displayCategory = dozyEvent.category
                } else {
                    let settings = allDisplaySettings.first(where: { $0.eventID == event.id })
                    displayCategory = settings?.category ?? event.category
                }
                originalPriority = displayPriority
                originalIsPinned = displayIsPinned
                originalCategory = displayCategory
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    showEditMemoAlert = false
                    showDeleteMemoAlert = false
                    showRecurringEditConfirm = false
                    showDozyDeleteConfirm = false
                    showCalendarDeleteConfirm = false
                }
            }
            .toolbar {
                if hasChanges {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("저장") {
                            onUpdateDisplaySettings?(event, displayPriority, displayIsPinned, displayCategory)
                            originalPriority = displayPriority
                            originalIsPinned = displayIsPinned
                            originalCategory = displayCategory
                        }
                        .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        let currentCategory = categories.first(where: { $0.name == displayCategory })
        let barColor: Color = {
            if event.source == .dozy, let cat = currentCategory {
                return Color(hex: cat.colorHex) ?? .blue
            }
            return Color(hex: event.calendarColorHex) ?? .blue
        }()
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor)
                .frame(width: 6, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let emoji = currentCategory?.emoji {
                        Text(emoji).font(.title3)
                    }
                    Text(event.title)
                        .font(.title2).fontWeight(.bold)
                }
                HStack(spacing: 6) {
                    Text(event.calendarName)
                        .font(.caption).foregroundStyle(.secondary)
                    if let partnerTag {
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                        Label(partnerTag, systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(UIColor.systemGray6), in: Capsule())
                    }
                }
            }
        }
        .padding()
    }

    /// 파트너 이벤트인 경우 파트너 닉네임(없으면 "파트너") 반환, 아니면 nil
    private var partnerTag: String? {
        guard let dozyEvent else { return nil }
        guard let calID = dozyEvent.sharedCalendarID else { return nil }
        guard let ownerID = dozyEvent.ownerID,
              ownerID != (authViewModel.currentUser?.id ?? "") else { return nil }
        return ActiveSharedCalendarStore.shared.partnerDisplayName(for: calID)
    }
    
    // MARK: - Info
    private var infoSection: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "clock", label: "시간", value: timeString)
            
            if let location = event.location, !location.isEmpty {
                Divider().padding(.leading, 52)
                DetailRow(icon: "mappin", label: "위치", value: location)
            }
            
            if let notes = event.notes, !notes.isEmpty {
                Divider().padding(.leading, 52)
                DetailRow(icon: "note.text", label: "설명", value: notes)
            }
            
            Divider().padding(.leading, 52)
            DetailRow(icon: sourceIcon, label: "캘린더", value: event.calendarName)
            
            if let dozyEvent, dozyEvent.recurrenceRule != "none" {
                Divider().padding(.leading, 52)
                DetailRow(icon: "repeat", label: "반복", value: recurrenceLabel(dozyEvent.recurrenceRule))
            }
            
            if let dozyEvent, dozyEvent.notificationMinutesBefore >= 0 {
                Divider().padding(.leading, 52)
                DetailRow(icon: "bell", label: "알림", value: notificationLabel(dozyEvent.notificationMinutesBefore))
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Memo
    private func memoSection(_ dozy: DozyEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.top, 8)
            
            Text("메모")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            ForEach(Array(memos.enumerated()), id: \.offset) { index, memo in
                HStack(alignment: .top, spacing: 8) {
                    Text("📝").font(.subheadline)
                    Text(memo)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
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
                .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
        }
        .alert("메모 삭제", isPresented: $showDeleteMemoAlert) {
            Button("삭제", role: .destructive) {
                if let index = deletingMemoIndex {
                    memos.remove(at: index)
                    dozy.memos = memos
                    onSaveMemos?(dozy)
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("정말로 삭제하시겠습니까?")
        }
        .alert("메모 수정", isPresented: $showEditMemoAlert) {
            TextField("메모", text: $editingMemoText)
            Button("저장") {
                if let index = editingMemoIndex {
                    memos[index] = editingMemoText
                    dozy.memos = memos
                    onSaveMemos?(dozy)
                }
            }
            Button("취소", role: .cancel) { }
        }
    }
    
    private func submitMemo(_ dozy: DozyEvent) {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        memos.append(trimmed)
        dozy.memos = memos
        onSaveMemos?(dozy)
        memoText = ""
    }
    
    // MARK: - Action (Dozy)

    // MARK: - Display Settings (표시 설정 카드)

    /// 내 이벤트용 — 토글/Picker로 편집 가능
    private var editableDisplaySettings: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $displayIsPinned) {
                Label("상단 고정", systemImage: displayIsPinned ? "pin.fill" : "pin")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider().padding(.leading)

            HStack {
                Label("우선순위", systemImage: "chart.bar").foregroundStyle(.primary)
                Spacer()
                Picker("", selection: $displayPriority) {
                    Text("없음").tag(0)
                    Text("높음 🔴").tag(1)
                    Text("중간 🟡").tag(2)
                    Text("낮음 🔵").tag(3)
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider().padding(.leading)

            HStack {
                Label("카테고리", systemImage: "tag").foregroundStyle(.primary)
                Spacer()
                Picker("", selection: $displayCategory) {
                    ForEach(categories) { cat in
                        Text("\(cat.emoji) \(cat.name)").tag(cat.name)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    /// 파트너 이벤트용 — 읽기 전용. 카테고리는 파트너가 설정한 값을 그대로 표시
    private func readOnlyDisplaySettings(for dozyEvent: DozyEvent) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("상단 고정", systemImage: dozyEvent.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dozyEvent.isPinned ? "ON" : "OFF")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.vertical, 12)

            Divider().padding(.leading)

            HStack {
                Label("우선순위", systemImage: "chart.bar").foregroundStyle(.secondary)
                Spacer()
                Text(priorityLabel(dozyEvent.priority))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.vertical, 10)

            Divider().padding(.leading)

            HStack {
                Label("카테고리", systemImage: "tag").foregroundStyle(.secondary)
                Spacer()
                Text(dozyEvent.category.isEmpty ? "-" : dozyEvent.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.vertical, 10)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func priorityLabel(_ value: Int) -> String {
        switch value {
        case 1: return "높음 🔴"
        case 2: return "중간 🟡"
        case 3: return "낮음 🔵"
        default: return "없음"
        }
    }

    private func dozyActionSection(_ dozyEvent: DozyEvent) -> some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 16)

            if event.isExternalMirror && event.externalDeleted {
                externalDeletedBanner
            }

            // 표시 설정 — 내 이벤트는 편집 가능, 파트너 이벤트는 읽기 전용
            if canEditEvent {
                editableDisplaySettings
                Text("Apple · Google 일정은 일정 색깔을 변경할 수 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                readOnlyDisplaySettings(for: dozyEvent)
            }

            if canEditEvent {
                if event.isExternalMirror {
                    // 외부 미러는 수정 버튼 없음(원본은 Apple/Google 앱에서 편집).
                    // 공유 자체만 해제 가능.
                    Button(role: .destructive) {
                        showDozyDeleteConfirm = true
                    } label: {
                        Label("공유 해제", systemImage: "person.2.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    .confirmationDialog("공유 해제", isPresented: $showDozyDeleteConfirm, titleVisibility: .visible) {
                        Button("공유 해제", role: .destructive) {
                            onDelete?(dozyEvent)
                        }
                    } message: {
                        Text("이 일정의 공유만 해제됩니다. 원본 Apple · Google 일정은 그대로 유지됩니다.")
                    }
                } else {
                    Button {
                        if dozyEvent.recurrenceRule != "none" {
                            showRecurringEditConfirm = true
                        } else {
                            dismiss()
                            onEdit?(dozyEvent)
                        }
                    } label: {
                        Label("수정", systemImage: "pencil").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .confirmationDialog("반복 일정 수정", isPresented: $showRecurringEditConfirm, titleVisibility: .visible) {
                        Button("모든 반복 일정 수정") {
                            dismiss()
                            onEdit?(dozyEvent)
                        }
                    } message: {
                        Text("반복 일정의 모든 항목이 수정됩니다.")
                    }

                    Button(role: .destructive) {
                        showDozyDeleteConfirm = true
                    } label: {
                        Label("삭제", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    .confirmationDialog(
                        dozyEvent.recurrenceRule != "none" ? "반복 일정 삭제" : "일정 삭제",
                        isPresented: $showDozyDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        if dozyEvent.recurrenceRule != "none" {
                            Button("이 일정만 삭제", role: .destructive) {
                                onDeleteThisOnly?(dozyEvent, event.startDate)
                                dismiss()
                            }
                            Button("이후 모든 일정 삭제", role: .destructive) {
                                onDeleteFutureEvents?(dozyEvent, event.startDate)
                                dismiss()
                            }
                            Button("모든 반복 일정 삭제", role: .destructive) {
                                onDelete?(dozyEvent)
                            }
                        } else {
                            Button("삭제", role: .destructive) {
                                onDelete?(dozyEvent)
                            }
                        }
                    } message: {
                        Text(dozyEvent.recurrenceRule != "none"
                             ? "삭제할 범위를 선택해주세요."
                             : "정말로 삭제하시겠습니까?")
                    }
                }
            } else {
                Label("파트너가 만든 일정은 수정 · 삭제할 수 없습니다.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
    }

    /// 외부 원본이 삭제된 미러 스냅샷에 대한 경고 배너. 소유자·파트너 모두에게 표시.
    private var externalDeletedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("원본이 삭제되었습니다", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
            Text("원본 Apple · Google 일정이 더이상 존재하지 않습니다. 공유 캘린더에서는 계속 표시되며, 소유자가 공유를 해제할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    // MARK: - Action (Apple / Google)

    private var calendarActionSection: some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 16)

            // 표시 설정
            VStack(spacing: 0) {
                Toggle(isOn: $displayIsPinned) {
                    Label("상단 고정", systemImage: displayIsPinned ? "pin.fill" : "pin")
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                Divider().padding(.leading)

                HStack {
                    Label("우선순위", systemImage: "chart.bar")
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $displayPriority) {
                        Text("없음").tag(0)
                        Text("높음 🔴").tag(1)
                        Text("중간 🟡").tag(2)
                        Text("낮음 🔵").tag(3)
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider().padding(.leading)

                HStack {
                    Label("카테고리", systemImage: "tag")
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $displayCategory) {
                        ForEach(categories) { cat in
                            Text("\(cat.emoji) \(cat.name)").tag(cat.name)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text("Apple · Google 일정은 일정 색깔을 변경할 수 없습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                dismiss()
                onEditCalendar?(event)
            } label: {
                Label("수정", systemImage: "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button(role: .destructive) {
                showCalendarDeleteConfirm = true
            } label: {
                Label("삭제", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 24)
            .confirmationDialog("일정 삭제", isPresented: $showCalendarDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    onDeleteCalendar?(event)
                    dismiss()
                }
            } message: {
                Text("정말로 삭제하시겠습니까?")
            }
        }
    }
    
    // MARK: - Helpers
    
    private var timeString: String {
        if event.isAllDay { return "종일" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M월 d일 (E) HH:mm"
        fmt.locale = Locale(identifier: "ko_KR")
        let start = fmt.string(from: event.startDate)
        fmt.dateFormat = "HH:mm"
        let end = fmt.string(from: event.endDate)
        return "\(start) ~ \(end)"
    }
    
    private var sourceIcon: String {
        switch event.source {
        case .apple: return "apple.logo"
        case .google: return "g.circle"
        case .naver: return "n.circle"
        case .dozy: return "d.circle.fill"
        }
    }
    
    private func recurrenceLabel(_ rule: String) -> String {
        switch rule {
        case "daily": return "매일"
        case "weekly": return "매주"
        case "monthly": return "매월"
        case "yearly": return "매년"
        default: return ""
        }
    }
    
    private func notificationLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "정시"
        case 60: return "1시간 전"
        default: return "\(minutes)분 전"
        }
    }
}

// MARK: - DetailRow

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .padding(.leading, 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption).foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.trailing, 16)
    }
}
