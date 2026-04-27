//
//  MacEventEditView.swift
//  Dozy AI (macOS)
//
//  M4.7 — 일정 생성/수정 시트. iOS EventEditView 와 동일한 EventEditViewModel 을
//  재사용하되 macOS Form 레이아웃과 toolbar 배치로 재구성.
//  카테고리/공유 캘린더 피커는 후속 페이즈로 유보.
//

import SwiftUI
import SwiftData

struct MacEventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EventEditViewModel
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]

    init(
        eventToEdit: DozyEvent?,
        selectedDate: Date,
        useTimeHint: Bool = false,
        onSave: @escaping (DozyEvent) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EventEditViewModel(
            eventToEdit: eventToEdit,
            selectedDate: selectedDate,
            sharedCalendars: [],
            useTimeHint: useTimeHint,
            onSave: onSave
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $viewModel.title)
                    Toggle("종일", isOn: $viewModel.isAllDay)

                    if viewModel.isAllDay {
                        DatePicker(
                            "날짜",
                            selection: $viewModel.startDate,
                            displayedComponents: .date
                        )
                        .environment(\.locale, .koreanForce24h)
                    } else {
                        DatePicker(
                            "시작",
                            selection: $viewModel.startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .environment(\.locale, .koreanForce24h)
                        DatePicker(
                            "종료",
                            selection: $viewModel.endDate,
                            in: viewModel.startDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .environment(\.locale, .koreanForce24h)
                    }
                }
                
                Section("카테고리") {
                    Picker("카테고리", selection: $viewModel.category) {
                        ForEach(categories) { cat in
                            Text("\(cat.emoji) \(cat.name)").tag(cat.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.category) { _, newName in
                        if let cat = categories.first(where: { $0.name == newName }) {
                            viewModel.selectedColor = Color(hex: cat.colorHex) ?? viewModel.selectedColor
                        }
                    }
                }

                Section("추가 정보") {
                    TextField("장소 (선택)", text: $viewModel.location)
                    TextField("메모 (선택)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("반복") {
                    Picker("반복", selection: $viewModel.recurrenceRule) {
                        Text("없음").tag("none")
                        Text("매일").tag("daily")
                        Text("매주").tag("weekly")
                        Text("매월").tag("monthly")
                        Text("매년").tag("yearly")
                    }

                    if viewModel.recurrenceRule != "none" {
                        DatePicker(
                            "반복 종료일",
                            selection: $viewModel.recurrenceEndDate,
                            displayedComponents: .date
                        )
                        .environment(\.locale, .koreanForce24h)
                    }
                }

                Section("알림") {
                    Picker("알림", selection: $viewModel.notificationMinutesBefore) {
                        Text("없음").tag(-1)
                        Text("정시").tag(0)
                        Text("5분 전").tag(5)
                        Text("10분 전").tag(10)
                        Text("15분 전").tag(15)
                        Text("30분 전").tag(30)
                        Text("1시간 전").tag(60)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(viewModel.isEditing ? "일정 수정" : "새 일정")
            .onAppear {
                if let cat = categories.first(where: { $0.name == viewModel.category }) {
                    viewModel.selectedColor = Color(hex: cat.colorHex) ?? viewModel.selectedColor
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        viewModel.save()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.isSavable)
                }
            }
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620)
    }
}
