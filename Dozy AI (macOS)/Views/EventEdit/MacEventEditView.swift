//
//  MacEventEditView.swift
//  Dozy AI (macOS)
//
//  M4.7 — 일정 생성/수정 시트. iOS EventEditView 와 동일한 EventEditViewModel 을
//  재사용하되 macOS Form 레이아웃과 toolbar 배치로 재구성.
//  새 일정일 때 맨 위에 자연어 한 줄 입력 섹션 — 파싱 결과로 폼을 채운다 (#100). 음성 입력은 iOS 전용.
//  parseUseCase 가 nil 이면 그 섹션을 그리지 않는다 (수정 모드 · 외부 호출부 호환).
//

import SwiftUI
import SwiftData

struct MacEventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EventEditViewModel
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @State private var showCategoryManagement = false

    /// 자연어 한 줄 → 폼 채우기. nil 이면 빠른 입력 섹션을 그리지 않는다.
    private let parseUseCase: ParseNaturalLanguageEventUseCase?
    @State private var quickText = ""
    @State private var isParsing = false
    @State private var parseError: String?
    @State private var parsedSourceLabel: String?
    @FocusState private var quickFieldFocused: Bool

    init(
        eventToEdit: DozyEvent?,
        selectedDate: Date,
        sharedCalendars: [SharedCalendar] = [],
        useTimeHint: Bool = false,
        parseUseCase: ParseNaturalLanguageEventUseCase? = nil,
        onSave: @escaping (DozyEvent) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EventEditViewModel(
            eventToEdit: eventToEdit,
            selectedDate: selectedDate,
            sharedCalendars: sharedCalendars,
            useTimeHint: useTimeHint,
            onSave: onSave
        ))
        self.parseUseCase = parseUseCase
    }

    var body: some View {
        NavigationStack {
            Form {
                if parseUseCase != nil, !viewModel.isEditing {
                    quickInputSection
                }

                Section("기본 정보") {
                    TextField("제목", text: $viewModel.title)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)
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
                
                Section {
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
                    Button {
                        showCategoryManagement = true
                    } label: {
                        Label("카테고리 관리", symbol: "pencil.line")
                            .font(.subheadline)
                    }
                } header: {
                    Text("카테고리")
                } footer: {
                    Text("카테고리 추가·수정·삭제는 카테고리 관리에서 할 수 있습니다.")
                }

                if !viewModel.sharedCalendars.isEmpty {
                    Section("공유 캘린더") {
                        Picker("공유", selection: $viewModel.sharedCalendarID) {
                            Text("없음").tag(String?.none)
                            ForEach(viewModel.sharedCalendars) { cal in
                                Label(cal.name, symbol: "person.2.fill")
                                    .tag(Optional(cal.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("추가 정보") {
                    LocationSearchField(
                        locationText: $viewModel.location,
                        resolvedLocation: $viewModel.resolvedLocation
                    )
                    TextField("메모 (선택)", text: $viewModel.notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)
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
            .sheet(isPresented: $showCategoryManagement) {
                MacCategoryManagementView()
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

    // MARK: - 빠른 입력 (자연어)

    private var quickInputSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(symbol: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DozyColor.Brand.primary)
                TextField("한 줄로 입력 (예: 내일 오후 3시 치과 30분)", text: $quickText)
                    .textFieldStyle(.roundedBorder)
                    .focused($quickFieldFocused)
                    .onSubmit { parseQuickText() }
                    .disabled(isParsing)

                if isParsing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("채우기") { parseQuickText() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(DozyColor.Brand.primary)
                        .disabled(quickText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        } header: {
            Text("빠른 입력")
        } footer: {
            if let parseError {
                Text(parseError).foregroundStyle(DozyColor.State.danger)
            } else if let parsedSourceLabel {
                Text("\(parsedSourceLabel) 결과로 채웠어요. 내용을 확인하고 저장하세요.")
            } else {
                Text("날짜·시간·장소가 들어간 문장을 적으면 아래 항목을 채워 드려요.")
            }
        }
    }

    private func parseQuickText() {
        guard let parseUseCase, !isParsing else { return }
        let text = quickText
        isParsing = true
        parseError = nil
        parsedSourceLabel = nil
        Task {
            defer { isParsing = false }
            do {
                let draft = try await parseUseCase.execute(text: text)
                withAnimation(.snappy(duration: 0.25)) { viewModel.apply(draft) }
                parsedSourceLabel = draft.sourceLabel
                quickFieldFocused = false
            } catch {
                parseError = (error as? DozyError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
