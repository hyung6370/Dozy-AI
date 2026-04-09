//
//  EventDetailView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import SwiftUI

struct EventDetailView: View {
    
    let event: CalendarEvent
    let dozyEvent: DozyEvent?
    let onEdit: ((DozyEvent) -> Void)?
    let onDelete: ((DozyEvent) -> Void)?
    let onEditCalendar: ((CalendarEvent) -> Void)?
    let onDeleteCalendar: ((CalendarEvent) -> Void)?
    let onSaveMemos: ((DozyEvent) -> Void)?
    let onUpdateDisplaySettings: ((CalendarEvent, Int, Bool, String?) -> Void)?

    @Environment(\.dismiss) private var dismiss
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
    @State private var displayCategory: WorkCategory = .general

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
                displayCategory = WorkCategory(rawValue: event.category) ?? .general
                print("📌 EventDetailView.onAppear: id=\(event.id.prefix(12)) event.category=\(event.category) → displayCategory=\(displayCategory.rawValue)")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: event.calendarColorHex) ?? .blue)
                .frame(width: 6, height: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.title2).fontWeight(.bold)
                Text(event.calendarName)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
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

    private func dozyActionSection(_ dozyEvent: DozyEvent) -> some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 16)

            // 표시 설정
            VStack(spacing: 0) {
                Toggle(isOn: $displayIsPinned) {
                    Label("상단 고정", systemImage: displayIsPinned ? "pin.fill" : "pin")
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .onChange(of: displayIsPinned) { _, newValue in
                    onUpdateDisplaySettings?(event, displayPriority, newValue, displayCategory.rawValue)
                }

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
                    .onChange(of: displayPriority) { _, newValue in
                        onUpdateDisplaySettings?(event, newValue, displayIsPinned, displayCategory.rawValue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider().padding(.leading)

                HStack {
                    Label("카테고리", systemImage: "tag")
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $displayCategory) {
                        ForEach(WorkCategory.allCases, id: \.self) { cat in
                            Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: displayCategory) { _, newValue in
                        onUpdateDisplaySettings?(event, displayPriority, displayIsPinned, newValue.rawValue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Button {
                dismiss()
                onEdit?(dozyEvent)
            } label: {
                Label("수정", systemImage: "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

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
                Button("삭제", role: .destructive) {
                    onDelete?(dozyEvent)
                }
            } message: {
                Text(dozyEvent.recurrenceRule != "none"
                     ? "모든 반복 일정이 함께 삭제됩니다. 정말 삭제하시겠습니까?"
                     : "정말로 삭제하시겠습니까?")
            }
        }
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
                .onChange(of: displayIsPinned) { _, newValue in
                    onUpdateDisplaySettings?(event, displayPriority, newValue, displayCategory.rawValue)
                }

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
                    .onChange(of: displayPriority) { _, newValue in
                        onUpdateDisplaySettings?(event, newValue, displayIsPinned, displayCategory.rawValue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider().padding(.leading)

                HStack {
                    Label("카테고리", systemImage: "tag")
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $displayCategory) {
                        ForEach(WorkCategory.allCases, id: \.self) { cat in
                            Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: displayCategory) { _, newValue in
                        onUpdateDisplaySettings?(event, displayPriority, displayIsPinned, newValue.rawValue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
