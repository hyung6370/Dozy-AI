//
//  MacEventEditView.swift
//  Dozy AI (macOS)
//
//  M4.7 — 일정 생성/수정 시트. iOS EventEditView 와 동일한 EventEditViewModel 을
//  재사용하되 macOS Form 레이아웃과 toolbar 배치로 재구성.
//  카테고리/공유 캘린더 피커는 후속 페이즈로 유보.
//

import SwiftUI

struct MacEventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EventEditViewModel

    init(eventToEdit: DozyEvent?, selectedDate: Date, onSave: @escaping (DozyEvent) -> Void) {
        _viewModel = StateObject(wrappedValue: EventEditViewModel(
            eventToEdit: eventToEdit,
            selectedDate: selectedDate,
            sharedCalendars: [],
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
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    } else {
                        DatePicker(
                            "시작",
                            selection: $viewModel.startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                        DatePicker(
                            "종료",
                            selection: $viewModel.endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                Section("색상") {
                    ColorPicker("일정 색상", selection: $viewModel.selectedColor, supportsOpacity: false)
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
                        .environment(\.locale, Locale(identifier: "ko_KR"))
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
