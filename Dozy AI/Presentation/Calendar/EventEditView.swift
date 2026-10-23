//
//  EventEditView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//
//  새 일정 / 일정 수정 화면. 시스템 Form 대신 앱의 카드 컴포넌트(DozyListSection·DozyListRow·DozyTintedIcon)로
//  구성한다 — 설정 화면과 같은 톤.
//    1) 제목 + 카테고리 칩 카드   2) 시간 카드   3) 장소·메모 카드   4) 반복·알림 카드   5) 공유 캘린더 카드(있을 때)
//

import SwiftUI
import SwiftData

struct EventEditView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EventEditViewModel
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    @State private var showAddCategory = false
    /// ZStack overlay 같이 @Environment(\.dismiss) 가 안 동작하는 컨텍스트에서 명시적 dismiss 콜백.
    /// nil 이면 기본 dismiss() 호출.
    private let onCancel: (() -> Void)?
    
    /// 자연어 한 줄 -> 폼 채우기. nil 이면 빠른 입력 카드를 그리지 않는다 (수정 모드, 외부 호출부 호환)
    private let parseUseCase: ParseNaturalLanguageEventUseCase?
    @State private var quickText = ""
    @State private var isParsing = false
    @State private var parseError: String?
    @State private var parsedSourceLabel: String?
    @FocusState private var quickFieldFocused: Bool
    /// 음성으로 한 줄 입력. nil 이면 마이크 버튼을 그리지 않는다.
    private let speechService: SpeechServiceProtocol?
    @State private var showVoiceInput = false

    init(eventToEdit: DozyEvent?, selectedDate: Date, sharedCalendars: [SharedCalendar] = [],
         parseUseCase: ParseNaturalLanguageEventUseCase? = nil,
         speechService: SpeechServiceProtocol? = nil,
         onSave: @escaping (DozyEvent) -> Void, onCancel: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: EventEditViewModel(
            eventToEdit: eventToEdit,
            selectedDate: selectedDate,
            sharedCalendars: sharedCalendars,
            onSave: onSave
        ))
        self.parseUseCase = parseUseCase
        self.speechService = speechService
        self.onCancel = onCancel
    }

    private func performDismiss() {
        if let onCancel { onCancel() } else { dismiss() }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DozySpacing.lg) {
                    if parseUseCase != nil, !viewModel.isEditing {
                        quickInputCard   // 자연어 한 줄 → 폼 채우기 (새 일정에서만)
                    }
                    titleCard
                    timeSection
                    detailSection
                    repeatAlarmSection
                    if !viewModel.sharedCalendars.isEmpty {
                        sharedCalendarSection
                    }
                }
                .padding(.vertical, DozySpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DozyColor.Background.grouped)
            .navigationTitle(viewModel.isEditing ? "일정 수정" : "새 일정")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { syncColor(with: viewModel.category) }
            .onChange(of: viewModel.category) { _, newName in syncColor(with: newName) }
            .sheet(isPresented: $showAddCategory) {
                CategoryEditSheet()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { performDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        viewModel.save()
                        performDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isSavable)
                }
            }
        }
    }

    /// 선택된 카테고리 색을 일정 색으로 — 제목 옆 색 바와 저장 시 colorHex 에 쓰인다.
    private func syncColor(with categoryName: String) {
        if let cat = categories.first(where: { $0.name == categoryName }) {
            viewModel.selectedColor = Color(hex: cat.colorHex) ?? viewModel.selectedColor
        }
    }
    
    // MARK: - 0) 빠른 입력 (자연어)
    
    private var quickInputCard: some View {
        VStack(alignment: .leading, spacing: DozySpacing.xs) {
            HStack(spacing: DozySpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DozyColor.Brand.primary)
                TextField("한 줄로 입력 (예: 내일 오후 3시 치과 30분)", text: $quickText)
                    .font(DozyFont.subheadline)
                    .focused($quickFieldFocused)
                    .submitLabel(.go)
                    .onSubmit { parseQuickText() }
                    .disabled(isParsing)

                if let speechService, !isParsing {
                    Button { showVoiceInput = true } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DozyColor.Brand.primary)
                            .frame(width: 28, height: 28)
                            .background(DozyColor.Brand.primary.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("음성으로 입력")
                    .accessibilityIdentifier("btn_quick_voice")
                    .sheet(isPresented: $showVoiceInput) {
                        VoiceInputView(speechService: speechService, style: .event) { text in
                            quickText = text
                            parseQuickText()   // 받아쓴 문장을 바로 파싱 → 폼 채움
                        }
                    }
                }
                
                if isParsing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("채우기") { parseQuickText() }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(DozyColor.Brand.primary)
                        .disabled(quickText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            if let parseError {
                Text(parseError)
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.State.danger)
            } else if let parsedSourceLabel {
                Text("\(parsedSourceLabel) 결과로 채웠어요. 내용을 확인하고 저장하세요.")
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
            } else {
                Text(speechService == nil
                     ? "날짜·시간·장소가 들어간 문장을 적으면 아래 항목을 채워 드려요."
                     : "문장을 적거나 마이크로 말하면 아래 항목을 채워 드려요.")
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
            }
        }
        .padding(DozySpacing.md)
        .clipShape(RoundedRectangle(cornerRadius: DozyRadius.lg, style: .continuous))
        .dozyThemedCardSurface(cornerRadius: DozyRadius.lg)
        .padding(.horizontal, DozySpacing.md)
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

    // MARK: - 1) 제목 + 카테고리

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: DozySpacing.md) {
            HStack(spacing: DozySpacing.sm) {
                // 카테고리 색 바 — 어떤 색으로 저장될지 바로 보인다.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(viewModel.selectedColor)
                    .frame(width: 4, height: 28)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.selectedColor)
                TextField("제목", text: $viewModel.title)
                    .font(.title3.weight(.semibold))
                    .submitLabel(.done)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DozySpacing.xs) {
                    ForEach(categories) { cat in
                        categoryChip(cat)
                    }
                    addCategoryChip
                }
                .padding(.horizontal, 1)   // 선택 칩의 stroke 가 잘리지 않게
            }
            .scrollClipDisabled()

            Text("카테고리는 설정에서 생성, 수정할 수 있습니다.")
                .font(DozyFont.caption)
                .foregroundStyle(DozyColor.Text.tertiary)
        }
        .padding(DozySpacing.md)
        .clipShape(RoundedRectangle(cornerRadius: DozyRadius.lg, style: .continuous))
        .dozyThemedCardSurface(cornerRadius: DozyRadius.lg)
        .padding(.horizontal, DozySpacing.md)
    }

    private func categoryChip(_ cat: UserCategory) -> some View {
        let isSelected = viewModel.category == cat.name
        let color = Color(hex: cat.colorHex) ?? DozyColor.Text.secondary
        return Button {
            withAnimation(.snappy(duration: 0.2)) { viewModel.category = cat.name }
        } label: {
            HStack(spacing: DozySpacing.xxs) {
                Text(cat.emoji)
                Text(cat.name)
                    .font(.footnote.weight(isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, DozySpacing.sm)
            .padding(.vertical, DozySpacing.xs)
            .foregroundStyle(DozyColor.Text.primary)
            .background(isSelected ? color.opacity(0.18) : DozyColor.Background.grouped, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? color : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var addCategoryChip: some View {
        Button { showAddCategory = true } label: {
            Label("추가", systemImage: "plus")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, DozySpacing.sm)
                .padding(.vertical, DozySpacing.xs)
                .foregroundStyle(DozyColor.Text.secondary)
                .overlay(
                    Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(DozyColor.Text.tertiary)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("카테고리 추가")
    }

    // MARK: - 2) 시간

    private var timeSection: some View {
        DozyListSection(header: "시간") {
            DozyListRow(title: "종일", titleFont: rowFont) {
                DozyTintedIcon(systemName: "sun.max.fill", tint: DozyColor.State.warning)
            } trailing: {
                Toggle("종일", isOn: $viewModel.isAllDay)
                    .labelsHidden()
                    .tint(DozyColor.Brand.primary)
            }

            if viewModel.isAllDay {
                DozyListRow(title: "날짜", titleFont: rowFont) {
                    DozyTintedIcon(systemName: "calendar")
                } trailing: {
                    DatePicker("날짜", selection: $viewModel.startDate, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, .current)
                }
            } else {
                DozyListRow(title: "시작", titleFont: rowFont) {
                    DozyTintedIcon(systemName: "clock.fill")
                } trailing: {
                    DatePicker("시작", selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .environment(\.locale, .current)
                }
                DozyListRow(title: "종료", titleFont: rowFont) {
                    DozyTintedIcon(systemName: "flag.checkered")
                } trailing: {
                    DatePicker("종료",
                               selection: $viewModel.endDate,
                               in: viewModel.startDate...,
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .environment(\.locale, .current)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: viewModel.isAllDay)
    }

    // MARK: - 3) 장소·메모

    private var detailSection: some View {
        DozyListSection(header: "장소·메모") {
            HStack(alignment: .top, spacing: DozySpacing.md) {
                DozyTintedIcon(systemName: "mappin.and.ellipse", tint: DozyColor.State.danger)
                LocationSearchField(
                    locationText: $viewModel.location,
                    resolvedLocation: $viewModel.resolvedLocation
                )
                .padding(.top, 6)   // 아이콘(32pt) 세로 중앙과 텍스트 베이스라인 맞춤
            }
            .padding(.horizontal, DozySpacing.md)
            .padding(.vertical, DozySpacing.sm)
            .frame(minHeight: 56)

            HStack(alignment: .top, spacing: DozySpacing.md) {
                DozyTintedIcon(systemName: "note.text", tint: DozyColor.Brand.secondary)
                TextField("메모 (선택)", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(2...6)
                    .font(DozyFont.subheadline)
                    .padding(.top, 6)
            }
            .padding(.horizontal, DozySpacing.md)
            .padding(.vertical, DozySpacing.sm)
            .frame(minHeight: 56)
        }
    }

    // MARK: - 4) 반복·알림

    private var repeatAlarmSection: some View {
        DozyListSection(header: "반복·알림") {
            DozyListRow(title: "반복", titleFont: rowFont) {
                DozyTintedIcon(systemName: "repeat", tint: DozyColor.State.success)
            } trailing: {
                Menu {
                    Picker("반복", selection: $viewModel.recurrenceRule) {
                        Text("없음").tag("none")
                        Text("매일").tag("daily")
                        Text("매주").tag("weekly")
                        Text("매월").tag("monthly")
                        Text("매년").tag("yearly")
                    }
                } label: {
                    menuValueLabel(recurrenceTitle)
                }
            }

            if viewModel.recurrenceRule != "none" {
                DozyListRow(title: "반복 종료일", titleFont: rowFont) {
                    DozyTintedIcon(systemName: "calendar.badge.checkmark", tint: DozyColor.State.success)
                } trailing: {
                    DatePicker("반복 종료일", selection: $viewModel.recurrenceEndDate, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, .current)
                }
            }

            DozyListRow(title: "알림", titleFont: rowFont) {
                DozyTintedIcon(systemName: "bell.fill", tint: DozyColor.State.info)
            } trailing: {
                Menu {
                    Picker("알림", selection: $viewModel.notificationMinutesBefore) {
                        Text("없음").tag(-1)
                        Text("정시").tag(0)
                        Text("5분 전").tag(5)
                        Text("10분 전").tag(10)
                        Text("15분 전").tag(15)
                        Text("30분 전").tag(30)
                        Text("1시간 전").tag(60)
                    }
                } label: {
                    menuValueLabel(notificationTitle)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: viewModel.recurrenceRule)
    }

    // MARK: - 5) 공유 캘린더

    private var sharedCalendarSection: some View {
        DozyListSection(header: "공유 캘린더") {
            DozyListRow(title: "공유", titleFont: rowFont) {
                DozyTintedIcon(systemName: "person.2.fill")
            } trailing: {
                Menu {
                    Picker("공유", selection: $viewModel.sharedCalendarID) {
                        Text("없음").tag(String?.none)
                        ForEach(viewModel.sharedCalendars) { cal in
                            Label(cal.name, systemImage: "person.2.fill")
                                .tag(Optional(cal.id))
                        }
                    }
                } label: {
                    menuValueLabel(sharedCalendarTitle)
                }
            }
        }
    }

    // MARK: - Helpers

    /// 섹션 안 행 제목 폰트 — 섹션 헤더는 그대로 두고 내용만 한 단계 작게.
    private let rowFont: Font = DozyFont.subheadlineEmphasized

    /// 메뉴 행의 우측 값 표시 — 현재 값 + 위아래 셰브론.
    private func menuValueLabel(_ text: String) -> some View {
        HStack(spacing: DozySpacing.xxs) {
            Text(text)
                .font(DozyFont.footnote)
                .foregroundStyle(DozyColor.Text.secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DozyColor.Text.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var recurrenceTitle: String {
        switch viewModel.recurrenceRule {
        case "daily":   return String(localized: "매일")
        case "weekly":  return String(localized: "매주")
        case "monthly": return String(localized: "매월")
        case "yearly":  return String(localized: "매년")
        default:        return String(localized: "없음")
        }
    }

    private var notificationTitle: String {
        switch viewModel.notificationMinutesBefore {
        case 0:  return String(localized: "정시")
        case 5:  return String(localized: "5분 전")
        case 10: return String(localized: "10분 전")
        case 15: return String(localized: "15분 전")
        case 30: return String(localized: "30분 전")
        case 60: return String(localized: "1시간 전")
        default: return String(localized: "없음")
        }
    }

    private var sharedCalendarTitle: String {
        viewModel.sharedCalendars.first(where: { $0.id == viewModel.sharedCalendarID })?.name
            ?? String(localized: "없음")
    }
}
