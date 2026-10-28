//
//  MacMenuBarQuickAddView.swift
//  Dozy AI (macOS)
//
//  M4.10 — 메뉴바 팝오버 안에서 빠르게 새 일정을 추가하는 인라인 폼.
//  제목 / 종일 / 시작·종료만 포함한 경량 UI. 그 외 필드(색상/반복/알림 등)는
//  앱 본체의 MacEventEditView 에서 편집.
//  맨 위 한 줄 입력에 "내일 오후 3시 치과 30분" 처럼 적고 채우기(↩)를 누르면 제목·시간이 채워진다 (#100).
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
    @State private var quickText = ""
    @State private var isParsing = false
    @State private var parseHint: String?
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
                    Image(symbol: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Image(symbol: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DozyColor.Brand.primary)
                TextField("한 줄로 입력 (예: 내일 오후 3시 치과 30분)", text: $quickText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { parseQuickText() }
                    .disabled(isParsing)
                if isParsing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("채우기") { parseQuickText() }
                        .controlSize(.small)
                        .disabled(quickText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let parseHint {
                Text(parseHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    private func parseQuickText() {
        guard !isParsing else { return }
        let text = quickText
        isParsing = true
        parseHint = nil
        Task { @MainActor in
            defer { isParsing = false }
            do {
                let draft = try await container.parseNaturalLanguageEventUseCase.execute(text: text)
                title = draft.title
                isAllDay = draft.isAllDay
                startDate = draft.startDate
                endDate = draft.isAllDay ? draft.startDate : draft.endDate
                parseHint = String(localized: "\(draft.sourceLabel) 결과로 채웠어요. 내용을 확인하고 저장하세요.")
            } catch {
                parseHint = (error as? DozyError)?.errorDescription ?? error.localizedDescription
            }
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
        container.createDozyEventUseCase.execute(event, method: .menubar)
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
