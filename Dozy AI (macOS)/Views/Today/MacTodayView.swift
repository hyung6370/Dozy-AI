//
//  MacTodayView.swift
//  Dozy AI (macOS)
//
//  M4.4 — Today 뷰. iOS HomeView 의 헤더/Focus/Stats/Event List 블록을
//  macOS 디테일 패널 맥락에 맞게 재구성. Banner/AI 요약/메모/날씨는
//  다음 페이즈로 유보.
//

import SwiftUI
import Lottie

struct MacTodayView: View {
    @ObservedObject var viewModel: MacHomeViewModel
    @EnvironmentObject private var authViewModel: MacAuthViewModel
    @EnvironmentObject private var container: DependencyContainer
    @State private var selectedEvent: CalendarEvent? = nil
    @Environment(\.macTheme) private var theme
    @State private var showNewEventSheet = false
    @State private var showSummarySheet = false
    @State private var showNotificationSheet = false
    /// 저녁 체크 시트가 떠 있는 동안 요약 요청이 오면 체크 시트를 닫은 뒤 요약을 연다 (시트 충돌 방지).
    @State private var pendingSummaryAfterCheck = false

    @State private var memoText: String = ""
    @State private var editingMemoIndex: Int? = nil
    @State private var editingMemoText: String = ""
    @State private var showEditMemoAlert = false
    @State private var deletingMemoIndex: Int? = nil
    @State private var showDeleteMemoAlert = false

    init(viewModel: MacHomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                focusCard
                statsRow

                // 스피너는 첫 로드에만. 이미 내용이 있으면 재로드(공유 캘린더 동기화 등) 중에도 그대로 둔다 —
                // 내용을 ProgressView 로 바꿔치기하면 알림이 연달아 올 때 카드가 깜빡인다 (#110).
                if viewModel.isLoading && !viewModel.hasLoadedOnce {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    if let summary = viewModel.dailySummary {
                        Button { showSummarySheet = true } label: {
                            aiSummaryPreview(summary)
                        }
                        .buttonStyle(.plain)
                    }
                    if !viewModel.todayEvents.isEmpty {
                        eventListSection
                    }
                    memoSection
                    if !viewModel.hasSummary {
                        aiGenerateButton
                    }
                }
                
                MacWeatherCardView()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 720, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .overlay {
            if viewModel.showSuccessAnimation {
                MacLottieView(name: "success", loopMode: .playOnce, animationSpeed: 1.8) {
                    viewModel.showSuccessAnimation = false
                }
                .scaleEffect(0.22)
                .allowsHitTesting(false)
            }
        }
        .navigationTitle("오늘")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNotificationSheet = true
                } label: {
                    Label("알림", symbol: viewModel.hasUnreadNotification ? "bell.badge.fill" : "bell")
                }
                .help("알림")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewEventSheet = true
                } label: {
                    Label("새 일정", symbol: "plus")
                }
                .help("새 일정 추가")
            }
        }
        .sheet(isPresented: $showNotificationSheet, onDismiss: {
            viewModel.refreshNotificationBadge()
        }) {
            MacNotificationListView(repository: container.notificationRepository)
        }
        .overlay {
            if viewModel.showSuccessAnimation {
                MacLottieView(name: "success", loopMode: .playOnce, animationSpeed: 1.8) {
                    viewModel.showSuccessAnimation = false
                }
                .scaleEffect(0.22)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            viewModel.loadTodayData()
            consumePendingOpenSummary()
        }
        .refreshable {
            viewModel.loadTodayData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestSummary)) { _ in
            requestSummarySheet()
        }
        // 저녁 요약 알림 탭 (MacAppDelegate). 뷰가 이미 떠 있으면 여기서, 아니면 onAppear 가 플래그를 소비한다.
        .onReceive(NotificationCenter.default.publisher(for: .dozyOpenDailySummary)) { _ in
            consumePendingOpenSummary()
        }
        .onChange(of: showSummarySheet) { _, isPresented in
            // 요약을 봤으면 오늘 저녁 알림은 생략한다 (오늘 요청만 제거, 내일 이후는 유지).
            // 요약을 보는 중에는 저녁 체크 프롬프트도 오늘은 띄우지 않는다.
            if isPresented {
                container.summaryReminderService.markSummaryViewed()
                viewModel.skipEveningCheckForToday()
            }
        }
        // 저녁 일정 체크 (#101). 18시 이후 완료 로드가 끝나면 MacHomeViewModel 이 하루 1회 켠다.
        .sheet(isPresented: $viewModel.showEveningCheck, onDismiss: {
            if pendingSummaryAfterCheck {
                pendingSummaryAfterCheck = false
                showSummarySheet = true
            }
        }) {
            MacEveningCheckSheet(viewModel: viewModel) { viewModel.showEveningCheck = false }
                .frame(minWidth: 520, idealWidth: 560, minHeight: 360, idealHeight: 420)
        }
        // Detail sheet — 모든 편집이 인라인으로 이루어짐
        .sheet(item: $selectedEvent) { event in
            MacEventDetailView(
                event: event,
                dozyEvent: viewModel.dozyEventsByID[event.id],
                currentUserID: authViewModel.currentUser?.id ?? "",
                partnerDisplayName: nil,
                sharedCalendars: viewModel.mySharedCalendars,
                onDelete: { dozy in
                    viewModel.deleteDozyEvent(dozy)
                    selectedEvent = nil
                },
                onDeleteThisOnly: { dozy, date in
                    viewModel.deleteThisOccurrence(dozy, date: date)
                    selectedEvent = nil
                },
                onDeleteFutureOccurrences: { dozy, date in
                    viewModel.deleteFutureOccurrences(dozy, from: date)
                    selectedEvent = nil
                },
                onSaveMemos: { dozy in
                    viewModel.saveMemos(for: dozy)
                },
                onSaveEvent: { saved in
                    viewModel.saveDozyEvent(saved)
                }
            )
        }
        // New sheet — 새 일정 생성
        .sheet(isPresented: $showNewEventSheet) {
            MacEventEditView(
                eventToEdit: nil,
                selectedDate: Date(),
                sharedCalendars: viewModel.mySharedCalendars,
                parseUseCase: container.parseNaturalLanguageEventUseCase,
                onSave: { saved in
                    viewModel.saveDozyEvent(saved)
                }
            )
        }
        // AI 요약 풀뷰 — 카드 탭 또는 "AI 요약 생성" 버튼에서 진입.
        // frame 은 sheet wrapper 에서만 — view body 안에 두면 sheet 닫을 때 parent
        // window 가 줄어드는 macOS layout 버그 발생.
        .sheet(isPresented: $showSummarySheet) {
            NavigationStack {
                MacDailySummaryView(
                    generateSummaryUseCase: container.generateDailySummaryUseCase,
                    fetchRecentLogsUseCase: container.fetchRecentLogsUseCase,
                    events: viewModel.todayEvents,
                    completedTasks: [],
                    pendingTasks: [],
                    memos: viewModel.todayLog?.memos ?? [],
                    completedEventCount: viewModel.completedCount,
                    existingSummary: viewModel.dailySummary,
                    onSummaryGenerated: { newSummary in
                        viewModel.dailySummary = newSummary
                    }
                )
            }
            .frame(minWidth: 640, idealWidth: 720, minHeight: 640, idealHeight: 720)
        }
        .alert("메모 수정", isPresented: $showEditMemoAlert) {
            TextField("메모", text: $editingMemoText)
            Button("저장") {
                if let index = editingMemoIndex {
                    viewModel.updateMemo(at: index, text: editingMemoText)
                }
                editingMemoIndex = nil
            }
            Button("취소", role: .cancel) { editingMemoIndex = nil }
        }
        .alert("메모 삭제", isPresented: $showDeleteMemoAlert) {
            Button("삭제", role: .destructive) {
                if let index = deletingMemoIndex {
                    viewModel.deleteMemo(at: index)
                }
                deletingMemoIndex = nil
            }
            Button("취소", role: .cancel) { deletingMemoIndex = nil }
        } message: {
            Text("정말로 삭제하시겠습니까?")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestRefresh)) { _ in
            viewModel.loadTodayData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestNewEvent)) { _ in
            showNewEventSheet = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image("Dozy-AI-60x60")
                .resizable()
                .interpolation(.high)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.todayDateString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(viewModel.greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: - Focus Card

    private var focusCard: some View {
        let currentEvent = viewModel.currentEvent
        let upcomingEvent = viewModel.upcomingEvent
        let displayEvent = currentEvent ?? upcomingEvent
        let label = currentEvent != nil ? "지금 일정" : upcomingEvent != nil ? "다음 일정" : ""
        let accent = displayEvent.flatMap { Color(hex: $0.calendarColorHex) } ?? theme.accent

        return VStack(alignment: .leading, spacing: 0) {
            if let event = displayEvent {
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentEvent != nil ? Color.green : accent)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(currentEvent != nil ? Color.green : accent)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .padding(.bottom, 14)

                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent)
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(event.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .lineLimit(2)

                        HStack(spacing: 14) {
                            Label(event.timeRangeString, symbol: "clock")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let location = event.location, !location.isEmpty {
                                Label(location, symbol: "mappin")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    Text(timeUntilLabel(event))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(timeUntilColor(event))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(timeUntilColor(event).opacity(0.12), in: Capsule())
                }
            } else {
                Button {
                    showNewEventSheet = true
                } label: {
                    HStack(spacing: 14) {
                        Image(symbol: "calendar.badge.plus")
                            .font(.title)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("오늘 일정이 없습니다")
                                .font(.body)
                                .fontWeight(.semibold)
                            Text("새로 추가해볼까요?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(symbol: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(displayEvent != nil
                    ? AnyShapeStyle(LinearGradient(
                        colors: [accent.opacity(0.08), accent.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(.regularMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accent.opacity(displayEvent != nil ? 0.15 : 0), lineWidth: 1)
        )
    }

    private func timeUntilLabel(_ event: CalendarEvent) -> String {
        let now = Date()
        if event.startDate <= now { return String(localized: "진행 중") }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        if minutes < 60 { return String(localized: "\(minutes)분 후") }
        return String(localized: "\(minutes / 60)시간 후")
    }

    private func timeUntilColor(_ event: CalendarEvent) -> Color {
        let now = Date()
        if event.startDate <= now { return .green }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        if minutes < 30 { return .orange }
        return theme.accent
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        let total = viewModel.eventCount
        let done = viewModel.completedCount
        let pending = viewModel.pendingCount
        let progress = total > 0 ? Double(done) / Double(total) : 0
        let pct = Int(progress * 100)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 진행도")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text("\(done) / \(total) 완료")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(progressColor(progress))
                    .contentTransition(.numericText())
            }

            // 진행률 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [progressColor(progress).opacity(0.7), progressColor(progress)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)

            HStack(spacing: 22) {
                progressLegend(icon: "checkmark.circle.fill", color: .green, value: done, label: "완료")
                progressLegend(icon: "clock.fill", color: .orange, value: pending, label: "남음")
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCardSurface(cornerRadius: 16)
    }

    private func progressLegend(icon: String, color: Color, value: Int, label: LocalizedStringKey) -> some View {
        HStack(spacing: 7) {
            Image(symbol: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            // 숫자만 표시 — verbatim 으로 추출 제외 ('%lld' 가 catalog 에 들어가는 노이즈 방지).
            Text(verbatim: "\(value)")
                .font(.body)
                .fontWeight(.bold)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func progressColor(_ value: Double) -> Color {
        switch value {
        case 1.0:       return .green
        case 0.5..<1.0: return theme.accent
        case 0.01..<0.5: return .orange
        default:        return .secondary
        }
    }

    // MARK: - Event List

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("오늘 일정")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 2)

            ForEach(viewModel.todayEvents) { event in
                // 공휴일은 read-only — 토글/상세 둘 다 비활성. nil 콜백을 받으면 MacEventRow 의
                // 해당 Button 이 .disabled(true) 처리됨.
                MacEventRow(
                    event: event,
                    isCompleted: viewModel.completionsByEventID[event.id] == true,
                    onToggleCompletion: event.isReadOnly ? nil : { viewModel.toggleCompletion(for: event) },
                    onSelect: event.isReadOnly ? nil : { selectedEvent = event }
                )
            }
        }
    }

    // MARK: - AI Summary Preview

    private func aiSummaryPreview(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Image(symbol: "sparkles")
                        .font(.subheadline)
                    Text("Dozy 요약")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .foregroundStyle(theme.accent)
                Spacer()
                Text("\(viewModel.scorePercentage)점")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(scoreColor(summary.productivityScore).opacity(0.15))
                    .foregroundStyle(scoreColor(summary.productivityScore))
                    .clipShape(Capsule())
            }

            Text(summary.summaryText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)

            if !summary.highlights.isEmpty {
                ForEach(Array(summary.highlights.prefix(3).enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: 8) {
                        Image(symbol: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .padding(.top, 5)
                        Text(h)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if !summary.nextActions.isEmpty {
                Divider().padding(.vertical, 2)
                ForEach(Array(summary.nextActions.prefix(3).enumerated()), id: \.offset) { _, action in
                    HStack(alignment: .top, spacing: 8) {
                        Image(symbol: "arrow.right.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.accent)
                            .padding(.top, 3)
                        Text(action)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [theme.accent.opacity(0.10), theme.accent.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.accentStroke, lineWidth: 1))
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return theme.accent
        case 0.4..<0.6: return .orange
        default:        return .red
        }
    }

    // MARK: - Memo Section

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("메모")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 2)

            if let log = viewModel.todayLog {
                ForEach(Array(log.memos.enumerated()), id: \.offset) { index, memo in
                    HStack(alignment: .top, spacing: 10) {
                        Text(verbatim: "📝").font(.body)
                        Text(memo)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    .contextMenu {
                        Button {
                            editingMemoIndex = index
                            editingMemoText = memo
                            showEditMemoAlert = true
                        } label: {
                            Label("수정", symbol: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingMemoIndex = index
                            showDeleteMemoAlert = true
                        } label: {
                            Label("삭제", symbol: "trash")
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("메모를 남겨보세요", text: $memoText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { submitMemo() }

                Button {
                    submitMemo()
                } label: {
                    Image(symbol: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    /// 요약 시트 열기. 저녁 체크 시트가 떠 있으면 먼저 닫고 onDismiss 에서 연다.
    private func requestSummarySheet() {
        if viewModel.showEveningCheck {
            pendingSummaryAfterCheck = true
            viewModel.showEveningCheck = false
        } else {
            showSummarySheet = true
        }
    }

    /// 요약 알림 탭(MacAppDelegate)이 켠 플래그를 소비해 요약 시트를 연다.
    private func consumePendingOpenSummary() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: MacAppDelegate.pendingOpenSummaryKey) else { return }
        defaults.set(false, forKey: MacAppDelegate.pendingOpenSummaryKey)
        requestSummarySheet()
    }

    private func submitMemo() {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addMemo(trimmed)
        memoText = ""
    }

    // MARK: - AI Generate Button

    private var aiGenerateButton: some View {
        // 생성·풀뷰 진입을 통합 — sheet 안에서 onAppear 가 generateSummary() 자동 호출.
        Button {
            showSummarySheet = true
        } label: {
            HStack(spacing: 14) {
                if viewModel.isSummarizing {
                    ProgressView().controlSize(.regular)
                } else {
                    Image(symbol: "sparkles")
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dozy 요약 생성")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(viewModel.isSummarizing
                         ? "Dozy가 분석 중입니다..."
                         : "오늘 하루를 AI가 분석합니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(symbol: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .themedCardSurface(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasData || viewModel.isSummarizing)
        .opacity(viewModel.hasData ? 1.0 : 0.5)
    }
}

// MARK: - MacStatCard

private struct MacStatCard: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String
    let color: Color
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(symbol: icon)
                    .font(.callout)
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let progress {
                ProgressView(value: progress)
                    .tint(color)
                    .scaleEffect(y: 0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .themedCardSurface(cornerRadius: 14)
    }
}
