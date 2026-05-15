//
//  HomeView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import SwiftUI
import Combine
import Lottie

struct HomeView: View {

    private let container: DependencyContainer
    @Binding var selectedTab: Int
    // ViewModel 은 MainTabView 에서 소유 — 캘린더 탭으로 진입한 사용자도 scenePhase active
    // 시 widget cache 가 갱신되도록 하기 위해 owner 를 상위로 hoist 함.
    @ObservedObject var viewModel: HomeViewModel
    @State private var memoText = ""
    @State private var showSummarySheet = false
    @State private var editingMemoIndex: Int? = nil
    @State private var editingMemoText = ""
    @State private var showEditMemoAlert = false
    @State private var deletingMemoIndex: Int? = nil
    @State private var showDeleteMemoAlert = false
    @State private var showNotificationSheet = false
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var pendingDozyEdit: DozyEvent? = nil
    @State private var pendingCalendarEdit: CalendarEvent? = nil
    @State private var dozyEventToEdit: DozyEvent? = nil
    @State private var calendarEventToEdit: CalendarEvent? = nil
    @State private var showCreateFromEmptyAlert = false
    @State private var showNewEventSheet = false
    @State private var showSharedCalendar = false
    /// 위젯 (accessoryRectangular) 탭으로 받은 eventID — todayEvents 가 아직 로드 전이면 보류.
    @State private var pendingWidgetEventID: String? = nil

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(container: DependencyContainer, selectedTab: Binding<Int>, viewModel: HomeViewModel) {
        self.container = container
        self._selectedTab = selectedTab
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    bannerSection
                    if !authViewModel.isLoggedIn {
                        loginPromptBanner
                    }
                    if !viewModel.isLoading {
                        if let summary = viewModel.dailySummary {
                            aiSummaryPreview(summary)
                        }
                        if let log = viewModel.todayLog, !log.aiSummary.isEmpty {
                            aiSummaryDetail(log)
                        }
                    }
                    focusCard
                    statsRow

                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        if !viewModel.todayEvents.isEmpty {
                            eventListSection
                        }
                        memoSection
                    }
                    WeatherCardView()
                    aiGenerateButton
                }
                .padding()
            }
            .overlay {
                if viewModel.showSuccessAnimation {
                    LottieView(name: "success", loopMode: .playOnce, animationSpeed: 1.8) {
                        viewModel.showSuccessAnimation = false
                    }
                    .scaleEffect(0.22)
                    .allowsHitTesting(false)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HomeTopBarView(
                    hasNotification: viewModel.hasNotification,
                    isLoggedIn: authViewModel.isLoggedIn,
                    onSharedCalendarTap: {
                        if authViewModel.isLoggedIn {
                            showSharedCalendar = true
                        } else {
                            selectedTab = 3
                        }
                    },
                    onNotificationTap: { showNotificationSheet = true },
                    onProfileTap: { selectedTab = 3 }
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .dozyThemedShellBackground()
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
            .refreshable { viewModel.loadTodayData() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    showSummarySheet = false
                    selectedEvent = nil
                    showEditMemoAlert = false
                    showDeleteMemoAlert = false
                    dozyEventToEdit = nil
                    calendarEventToEdit = nil
                    showCreateFromEmptyAlert = false
                    showNewEventSheet = false
                }
            }
            .onAppear {
                viewModel.loadTodayData()
                viewModel.refreshNotificationBadge()
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 0 { viewModel.loadTodayData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dozyWidgetOpenEventDetail)) { notification in
                // 위젯 accessoryRectangular 탭 → 해당 eventID 의 상세 시트 오픈.
                // todayEvents 가 이미 로드돼 있으면 즉시 표시, 아니면 보류했다가 로드 후 시도.
                guard let id = notification.object as? String else { return }
                if let event = viewModel.todayEvents.first(where: { $0.id == id }) {
                    selectedEvent = event
                } else {
                    pendingWidgetEventID = id
                    viewModel.loadTodayData()
                }
            }
            .onChange(of: viewModel.todayEvents.count) { _, _ in
                // todayEvents 가 새로 로드된 직후, 보류된 widget eventID 가 있으면 해소.
                guard let id = pendingWidgetEventID,
                      let event = viewModel.todayEvents.first(where: { $0.id == id }) else { return }
                selectedEvent = event
                pendingWidgetEventID = nil
            }
            .alert("권한 필요", isPresented: $viewModel.showPermissionAlert) {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "캘린더와 미리알림 접근 권한이 필요합니다.")
            }
            .alert("메모 삭제", isPresented: $showDeleteMemoAlert) {
            Button("삭제", role: .destructive) {
                if let index = deletingMemoIndex {
                    viewModel.deleteMemo(at: index)
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
                    viewModel.updateMemo(at: index, text: editingMemoText)
                }
            }
            Button("취소", role: .cancel) { }
        }
        .navigationDestination(isPresented: $showNotificationSheet) {
            NotificationListView(repository: container.notificationRepository)
        }
        .navigationDestination(isPresented: $showSharedCalendar) {
            SharedCalendarListView(container: container)
        }
        .onChange(of: showNotificationSheet) { _, isShowing in
            guard !isShowing else { return }
            viewModel.refreshNotificationBadge()
        }
        .sheet(isPresented: $showSummarySheet) {
            DailySummaryView(
                generateSummaryUseCase: container.generateDailySummaryUseCase,
                fetchRecentLogsUseCase: container.fetchRecentLogsUseCase,
                events: viewModel.todayEvents,
                completedTasks: viewModel.completedTasks,
                pendingTasks: viewModel.pendingTasks,
                memos: viewModel.todayLog?.memos ?? [],
                completedEventCount: viewModel.completedCount,
                existingSummary: viewModel.dailySummary,
                onSummaryGenerated: { summary in
                    viewModel.dailySummary = summary
                }
            )
        }
        .sheet(item: $selectedEvent, onDismiss: {
            if let pending = pendingDozyEdit {
                dozyEventToEdit = pending
                pendingDozyEdit = nil
            } else if let pending = pendingCalendarEdit {
                calendarEventToEdit = pending
                pendingCalendarEdit = nil
            }
        }) { event in
            EventDetailView(
                event: event,
                dozyEvent: viewModel.dozyEventsByID[event.id],
                onEdit: { dozy in pendingDozyEdit = dozy; selectedEvent = nil },
                onDelete: { dozy in viewModel.deleteDozyEvent(dozy); selectedEvent = nil },
                onDeleteThisOnly: { dozy, date in viewModel.deleteThisOccurrence(dozy, date: date); selectedEvent = nil },
                onDeleteFutureEvents: { dozy, date in viewModel.deleteFutureOccurrences(dozy, from: date); selectedEvent = nil },
                onEditCalendar: { ev in pendingCalendarEdit = ev; selectedEvent = nil },
                onDeleteCalendar: { ev in viewModel.deleteCalendarEvent(ev); selectedEvent = nil },
                onSaveMemos: { viewModel.saveMemos(for: $0) },
                onUpdateDisplaySettings: { ev, priority, isPinned, category in
                    viewModel.updateDisplaySettings(for: ev, priority: priority, isPinned: isPinned, category: category)
                }
            )
        }
        .sheet(item: $dozyEventToEdit) { dozy in
            EventEditView(
                eventToEdit: dozy,
                selectedDate: dozy.startDate
            ) { saved in
                viewModel.saveDozyEvent(saved)
            }
        }
        .sheet(item: $calendarEventToEdit) { ev in
            CalendarEventEditView(event: ev) { edit in
                viewModel.saveCalendarEvent(ev, edit: edit)
            }
        }
        .alert("새로운 일정을 만들어볼까요?", isPresented: $showCreateFromEmptyAlert) {
            Button("만들기") { showNewEventSheet = true }
            Button("취소", role: .cancel) { }
        }
        .sheet(isPresented: $showNewEventSheet) {
            EventEditView(eventToEdit: nil, selectedDate: Date()) { saved in
                viewModel.saveDozyEvent(saved)
            }
        }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text(greeting)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "좋은 아침이에요 ☀️")
        case 12..<18: return String(localized: "좋은 오후예요 🌤️")
        case 18..<21: return String(localized: "좋은 저녁이에요 🌙")
        default: return String(localized: "안녕하세요 🌟")
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        BannerView(items: BannerItem.placeholders, interval: 4)
    }
    
    private var loginPromptBanner: some View {
        LoginPromptTooltipView {
            selectedTab = 3
        }
    }

    // MARK: - Focus Card

    private var focusCard: some View {
        let now = Date()
        let currentEvent = viewModel.todayEvents.first(where: { $0.startDate <= now && $0.endDate > now })
        let upcomingEvent = currentEvent == nil
            ? viewModel.todayEvents.first(where: { $0.startDate > now })
            : nil
        let displayEvent = currentEvent ?? upcomingEvent
        let label = currentEvent != nil ? "지금 일정" : upcomingEvent != nil ? "다음 일정" : ""
        let icon = currentEvent != nil ? "circle.fill" : "clock"

        return VStack(alignment: .leading, spacing: 0) {
            if let event = displayEvent {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(currentEvent != nil ? .green : .secondary)
                    Text(label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)

                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: event.calendarColorHex) ?? .blue)
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            Label(event.timeRangeString, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let location = event.location, !location.isEmpty {
                                Label(location, systemImage: "mappin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    Text(timeUntilLabel(event))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(timeUntilColor(event))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(timeUntilColor(event).opacity(0.1), in: Capsule())
                }
            } else {
                if viewModel.todayEvents.isEmpty {
                    Button {
                        showCreateFromEmptyAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.minus")
                                .font(.title3)
                                .foregroundStyle(Color.secondary)
                            Text("오늘 일정이 없습니다.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showCreateFromEmptyAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.green)
                            Text("남은 일정이 없습니다.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .dozyThemedCardBorder(cornerRadius: 14)
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
        return .blue
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            HomeStatCard(value: "\(viewModel.eventCount)", label: "오늘 일정", icon: "calendar", color: .blue)
            HomeStatCard(
                value: "\(viewModel.completedCount)/\(viewModel.completedCount + viewModel.pendingCount)",
                label: "할 일 완료",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    // MARK: - Event List

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘 일정")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            if viewModel.showSourceTabs {
                sourceFilterTabs
            }

            ForEach(viewModel.filteredEvents) { event in
                EventRow(event: event, isCompleted: viewModel.completionsByEventID[event.id] == true)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedEvent = event }
            }
        }
    }

    private var sourceFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterTab(label: "전체", icon: "calendar", isSelected: viewModel.selectedSource == nil) {
                    viewModel.selectedSource = nil
                }
                ForEach(viewModel.availableSources, id: \.self) { source in
                    FilterTab(label: source.displayName, icon: source.iconName, isSelected: viewModel.selectedSource == source) {
                        viewModel.selectedSource = source
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - AI Summary Preview

    private func aiSummaryPreview(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dozy 요약", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo)
                Spacer()
                Text("\(viewModel.scorePercentage)점")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor(summary.productivityScore).opacity(0.12))
                    .foregroundStyle(scoreColor(summary.productivityScore))
                    .clipShape(Capsule())
            }

            Text(summary.summaryText)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)

            if !summary.highlights.isEmpty {
                ForEach(Array(summary.highlights.prefix(2).enumerated()), id: \.offset) { _, highlight in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                        Text(highlight)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            HStack {
                Spacer()
                Text("상세 보기")
                    .font(.caption2)
                    .foregroundStyle(.indigo)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.indigo)
            }
        }
        .padding(14)
        .background(Color.indigo.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.indigo.opacity(0.1), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.loadTodayData()
            showSummarySheet = true
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default:        return .red
        }
    }

    // MARK: - Memo

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("메모")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            if let log = viewModel.todayLog {
                ForEach(Array(log.memos.enumerated()), id: \.offset) { index, memo in
                    HStack(alignment: .top, spacing: 8) {
                        Text(verbatim: "📝").font(.subheadline)
                        Text(memo)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
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
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("메모를 남겨보세요", text: $memoText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...)

                Button { submitMemo() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func submitMemo() {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addMemo(trimmed)
        memoText = ""
    }

    // MARK: - AI Generate Button

    private var aiGenerateButton: some View {
        Button {
            if viewModel.hasSummary {
                viewModel.loadTodayData()
                showSummarySheet = true
            } else { viewModel.generateAISummary() }
        } label: {
            HStack(spacing: 12) {
                if viewModel.isSummarizing {
                    ProgressView().tint(.indigo)
                } else {
                    Image(systemName: viewModel.hasSummary ? "brain.head.profile" : "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.hasSummary ? "Dozy 일정 요약 보기" : "Dozy 일정 요약 생성")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(viewModel.isSummarizing
                         ? "Dozy가 분석 중입니다..."
                         : viewModel.hasSummary
                         ? "생산성 점수: \(viewModel.scorePercentage)점"
                         : "오늘 하루를 AI가 분석합니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .dozyThemedCardBorder(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasData || viewModel.isSummarizing)
        .opacity(viewModel.hasData ? 1.0 : 0.5)
    }

    // MARK: - AI Summary Detail

    private func aiSummaryDetail(_ log: WorkLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dozy 일정 요약")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.dailySummary?.summaryText ?? log.aiSummary)
                    .font(.subheadline)
                    .lineSpacing(4)

                if !log.highlights.isEmpty {
                    Divider()
                    Text("핵심 하이라이트")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(log.highlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "star.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                if !log.nextActions.isEmpty {
                    Divider()
                    Text("추천 다음 할 일")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(log.nextActions, id: \.self) { action in
                        Label(action, systemImage: "arrow.right.circle")
                            .font(.caption).foregroundStyle(.blue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - HomeStatCard

private struct HomeStatCard: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .dozyThemedCardBorder(cornerRadius: 12)
    }
}
