//
//  MacMenuBarQuickAddView.swift
//  Dozy AI (macOS)
//
//  M4.10 — 메뉴바 팝오버 안에서 빠르게 새 일정을 추가하는 인라인 폼.
//  제목 / 종일 / 시작·종료만 포함한 경량 UI. 그 외 필드(색상/반복/알림 등)는
//  앱 본체의 MacEventEditView 에서 편집.
//

import SwiftUI
import Combine

struct MacMenuBarQuickAddView: View {
    let container: DependencyContainer
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    init(
        container: DependencyContainer,
        onSaved: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.container = container
        self.onSaved = onSaved
        self.onCancel = onCancel
        let cal = Calendar.current
        let defaultStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let defaultEnd   = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
        _startDate = State(initialValue: defaultStart)
        _endDate   = State(initialValue: defaultEnd)
    }

    var isSavable: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("새 일정")
                    .font(.headline)
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            TextField("제목", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submit() }

            Toggle("종일", isOn: $isAllDay)
                .font(.caption)

            if isAllDay {
                DatePicker("날짜", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .environment(\.locale, .current)
            } else {
                DatePicker("시작", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .environment(\.locale, .current)
                DatePicker("종료", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .environment(\.locale, .current)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("취소") { onCancel() }
                Spacer()
                Button {
                    submit()
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("저장")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isSavable)
            }
            .padding(.top, 4)
        }
    }

    private func submit() {
        guard isSavable else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let finalEnd = isAllDay ? startDate : endDate
        let event = DozyEvent(
            title: trimmed,
            startDate: startDate,
            endDate: finalEnd,
            isAllDay: isAllDay
        )
        isSaving = true
        errorMessage = nil
        container.createDozyEventUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSaving = false
                    if case .failure(let error) = completion {
                        errorMessage = error.errorDescription
                    }
                },
                receiveValue: { _ in
                    onSaved()
                }
            )
            .store(in: &cancellables)
    }
}
