//
//  HomeView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import SwiftUI
import Combine
import Lottie
import OSLog

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

    // 토스 스타일 Pull-to-Refresh 상태 — 상단바 내부 요소의 scale/인디케이터를 구동한다.
    @State private var pullProgress: Double = 0
    @State private var isRefreshing: Bool = false

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(container: DependencyContainer, selectedTab: Binding<Int>, viewModel: HomeViewModel) {
        self.container = container
        self._selectedTab = selectedTab
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            TossPullToRefreshScroll(
                threshold: 70,
                pullProgress: $pullProgress,
                isRefreshing: $isRefreshing,
                onRefresh: { await runRefresh() }
            ) {
                VStack(spacing: 20) {
                    headerSection
                    bannerSection
                    aiGenerateButton
                    if !authViewModel.isLoggedIn {
                        loginPromptBanner
                    }
                    if !viewModel.isLoading {
                        if let summary = viewModel.dailySummary {
                            aiSummaryPreview(summary)
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
                    onProfileTap: { selectedTab = 3 },
                    pullProgress: pullProgress,
                    isRefreshing: isRefreshing
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
                Logger.nav.info("[화면: 홈] 🧭 onAppear")
                viewModel.loadTodayData()
                viewModel.refreshNotificationBadge()
            }
            .onDisappear { Logger.nav.info("[화면: 홈] 🧭 onDisappear") }
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
                // 카드 전체(label + 일정 정보) 를 탭 가능하게 → 일정 상세 sheet 오픈.
                // 상세에서의 수정/삭제는 .sheet(item: $selectedEvent) wiring 으로 viewModel 경유 서버 반영.
                Button {
                    selectedEvent = event
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundStyle(currentEvent != nil ? .green : .secondary)
                            Text(label)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Spacer()
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
                                    .foregroundStyle(.primary)

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
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

    // MARK: - Pull to Refresh

    /// 토스 스타일 Pull-to-Refresh 의 실제 데이터 reload.
    /// `loadTodayData()` 는 동기 함수지만 내부적으로 Combine 체인을 띄우고 `isLoading`
    /// 을 즉시 true 로 세팅하므로, 그 flag 가 false 로 떨어질 때까지 폴링한다.
    private func runRefresh() async {
        viewModel.loadTodayData()
        // isLoading 가 즉시 true 로 바뀌지 않는 경로를 대비해 한 틱 대기.
        try? await Task.sleep(nanoseconds: 50_000_000)
        let deadline = Date().addingTimeInterval(5)
        while viewModel.isLoading && Date() < deadline {
            try? await Task.sleep(nanoseconds: 60_000_000)
        }
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

}

// MARK: - Toss-style Pull-to-Refresh

/// 토스 앱 스타일의 커스텀 Pull-to-Refresh 스크롤뷰.
///
/// 책임:
/// - 내부에 SwiftUI `ScrollView` 를 띄우고, 그 안에 UIKit 인트로스펙터 뷰를
///   심어 ancestor `UIScrollView` 의 `contentOffset` 과 `panGestureRecognizer`
///   state 를 직접 관찰한다.
/// - 결과로 얻는 당김 거리/release 시점을 `pullProgress` / `isRefreshing`
///   바인딩으로 외부에 노출한다.
///
/// 왜 PreferenceKey + DragGesture 가 아닌가:
/// - `safeAreaInset` 과 결합된 SwiftUI ScrollView 에서 GeometryReader-기반
///   offset 측정이 불안정 (변화가 누락되거나 처음 한 번만 fire).
/// - `simultaneousGesture(DragGesture(minimumDistance: 0))` 는 iOS 17 에서
///   ScrollView 의 pan 인식을 가로채는 케이스가 있음.
/// - 토스 자체가 UIKit 기반인 이유이기도 함 — UIScrollView 의 contentOffset/
///   panGesture 를 직접 들여다보는 게 가장 안정적.
private struct TossPullToRefreshScroll<Content: View>: View {
    let threshold: CGFloat
    @Binding var pullProgress: Double
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    @ViewBuilder var content: () -> Content

    @State private var hapticArmed = false
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// 인디케이터의 alpha — 로딩 중이면 1.0, 아니면 진행도와 동일하게 등장.
    private var indicatorOpacity: Double {
        if isRefreshing { return 1.0 }
        return min(max(pullProgress, 0), 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 0-높이 인트로스펙터 — superview chain 을 타고 올라가
                // ancestor UIScrollView 를 찾아 contentOffset / panGesture 를 관찰.
                TossScrollIntrospector(
                    onPullUpdate: handle(pull:),
                    onRelease: handleRelease
                )
                .frame(width: 0, height: 0)

                content()
            }
        }
        // 인디케이터는 ScrollView 의 visible top 에 고정 — 상단바 바로 아래,
        // iOS 기본 Pull-to-Refresh 가 스피너를 띄우는 그 위치. ScrollView 의
        // 콘텐츠가 당겨져 내려갈 때 그 영역이 드러나면서 자연스럽게 등장한다.
        .overlay(alignment: .top) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.regular)
                .tint(.secondary)
                .padding(.top, 16)
                .opacity(indicatorOpacity)
                .allowsHitTesting(false)
        }
        .task { hapticGenerator.prepare() }
    }

    private func handle(pull: CGFloat) {
        // 로딩 중에는 진행도를 외부에서 minScale 로 고정해 두므로 건드리지 않는다.
        guard !isRefreshing else { return }

        let progress = Double(pull / threshold)
        pullProgress = progress

        // 임계점 도달 — "지금 놓으면 refresh 됩니다" 햅틱 (1회/사이클).
        if progress >= 1.0 && !hapticArmed {
            hapticArmed = true
            hapticGenerator.impactOccurred()
            hapticGenerator.prepare()
        } else if progress < 0.5 {
            // 같은 제스처 안에서 사용자가 다시 위로 끌어올렸다 다시 내릴 수 있도록 재무장.
            hapticArmed = false
        }
    }

    private func handleRelease() {
        guard !isRefreshing else { return }
        guard pullProgress >= 1.0 else { return }

        isRefreshing = true
        hapticArmed = false

        Task {
            let start = Date()
            await onRefresh()
            // 너무 빠른 완료 (캐시 hit 등) 는 스피너가 깜빡이는 인상을 줘서
            // 최소 표시 시간을 보장한다.
            let minDuration: TimeInterval = 0.6
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < minDuration {
                let remaining = minDuration - elapsed
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            await MainActor.run { finishRefresh() }
        }
    }

    private func finishRefresh() {
        // 핵심 탄성 복원 — dampingFraction 0.45 로 통통 1~2회 오버슈트.
        // pullProgress = 0 과 isRefreshing = false 를 같은 트랜잭션에 묶어서
        // 상단바의 scale 1.0 복귀 + indicator 페이드아웃이 한 번에 일어난다.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.45)) {
            isRefreshing = false
            pullProgress = 0
        }
    }
}

/// UIKit 인트로스펙터 — superview chain 에서 첫 번째 `UIScrollView` 를 찾아
/// `contentOffset` KVO + pan gesture state 콜백을 hook 한다.
private struct TossScrollIntrospector: UIViewRepresentable {
    let onPullUpdate: (CGFloat) -> Void
    let onRelease: () -> Void

    func makeUIView(context: Context) -> TossIntrospectorView {
        let view = TossIntrospectorView()
        context.coordinator.onPullUpdate = onPullUpdate
        context.coordinator.onRelease = onRelease
        view.onAttached = { [weak coordinator = context.coordinator] hostView in
            coordinator?.attach(from: hostView)
        }
        return view
    }

    func updateUIView(_ uiView: TossIntrospectorView, context: Context) {
        // 부모가 closure 를 새로 만들어 전달해도 같은 동작을 유지.
        context.coordinator.onPullUpdate = onPullUpdate
        context.coordinator.onRelease = onRelease
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var onPullUpdate: ((CGFloat) -> Void)?
        var onRelease: (() -> Void)?
        private weak var scrollView: UIScrollView?
        private var offsetObservation: NSKeyValueObservation?

        func attach(from view: UIView) {
            guard let sv = view.findAncestorScrollView() else { return }
            guard sv !== scrollView else { return }
            scrollView = sv

            // contentOffset.y 가 -adjustedContentInset.top 보다 더 작아질 때 (= 위로 끌려 내려갔을 때)
            // 그 차이가 곧 당김 거리.
            offsetObservation = sv.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
                let pull = max(0, -scroll.contentOffset.y - scroll.adjustedContentInset.top)
                self?.onPullUpdate?(pull)
            }

            // pan gesture state 변화 — .ended / .cancelled / .failed 가 곧 release.
            sv.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
        }

        @objc private func panChanged(_ gr: UIPanGestureRecognizer) {
            switch gr.state {
            case .ended, .cancelled, .failed:
                onRelease?()
            default:
                break
            }
        }

        deinit {
            offsetObservation?.invalidate()
        }
    }
}

/// `didMoveToWindow` 시점에 introspection 을 트리거하는 호스트 뷰.
/// 첫 호출 시점에는 superview chain 이 완성됐다고 보장되지만, 안전을 위해
/// 한 runloop 미뤄서 ancestor 탐색 (auto layout 완료 후) 한다.
private final class TossIntrospectorView: UIView {
    var onAttached: ((UIView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onAttached?(self)
        }
    }
}

private extension UIView {
    func findAncestorScrollView() -> UIScrollView? {
        var current: UIView? = self.superview
        while let v = current {
            if let sv = v as? UIScrollView { return sv }
            current = v.superview
        }
        return nil
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

