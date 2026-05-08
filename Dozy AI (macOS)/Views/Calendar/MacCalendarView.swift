//
//  MacCalendarView.swift
//  Dozy AI (macOS)
//
//  M4.5 — 월별 캘린더 뷰. 6주×7일 그리드 + 선택된 날짜의 이벤트 리스트.
//  이벤트 클릭 → MacEventDetailView, "+" → MacEventEditView.
//

import SwiftUI
import AppKit
import Combine
import Lottie

struct MacCalendarView: View {
    @ObservedObject var viewModel: MacCalendarViewModel
    @StateObject private var swipeState = MonthSwipeState()
    @EnvironmentObject private var authViewModel: MacAuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var showNewEventSheet = false
    @State private var newEventTimeHint: Date? = nil
    @State private var eventPendingDelete: CalendarEvent? = nil
    @State private var showMonthPicker = false
    @State private var pickerYear = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth = Calendar.current.component(.month, from: Date())
    @State private var showFilterPopover = false

    init(viewModel: MacCalendarViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Context menu handlers

    private func handleEditEvent(_ event: CalendarEvent) {
        selectedEvent = event
    }

    private func handleDeleteEvent(_ event: CalendarEvent) {
        eventPendingDelete = event
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            if viewModel.viewMode == .month {
                weekdayHeader
                Divider()
                pagingMonthArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                eventListSection
                    .frame(height: 180)
            } else if viewModel.viewMode == .week {
                Divider()
                MacCalendarWeekView(
                    weekDates: weekDates(),
                    selectedDate: viewModel.selectedDate,
                    eventsByDate: viewModel.eventsByDate,
                    onSelectDate: { viewModel.selectDate($0) },
                    onSelectEvent: { selectedEvent = $0 },
                    onCreateEvent: { date in
                        viewModel.selectDate(date)
                        newEventTimeHint = nil
                        showNewEventSheet = true
                    },
                    onCreateEventAt: { dateTime in
                        viewModel.selectDate(dateTime)
                        newEventTimeHint = dateTime
                        showNewEventSheet = true
                    },
                    onEditEvent: handleEditEvent,
                    onDeleteEvent: handleDeleteEvent
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { swipeState.viewWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, w in swipeState.viewWidth = w }
                    }
                )
                .id(MacCalendarViewModel.startOfWeek(for: viewModel.currentMonth))
                .transition(weekDayTransition)
                .onContinuousHover { phase in
                    switch phase {
                    case .active: swipeState.isHovering = true
                    case .ended:  swipeState.isHovering = false
                    }
                }
            } else { // .day
                Divider()
                MacCalendarDayView(
                    date: viewModel.currentMonth,
                    eventsByDate: viewModel.eventsByDate,
                    onSelectEvent: { selectedEvent = $0 },
                    onCreateEvent: { date in
                        viewModel.selectDate(date)
                        newEventTimeHint = nil
                        showNewEventSheet = true
                    },
                    onCreateEventAt: { dateTime in
                        viewModel.selectDate(dateTime)
                        newEventTimeHint = dateTime
                        showNewEventSheet = true
                    },
                    onEditEvent: handleEditEvent,
                    onDeleteEvent: handleDeleteEvent
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { swipeState.viewWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, w in swipeState.viewWidth = w }
                    }
                )
                .id(Calendar.current.startOfDay(for: viewModel.currentMonth))
                .transition(weekDayTransition)
                .onContinuousHover { phase in
                    switch phase {
                    case .active: swipeState.isHovering = true
                    case .ended:  swipeState.isHovering = false
                    }
                }
            }
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
        .navigationTitle("캘린더")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFilterPopover.toggle()
                } label: {
                    Image(colorScheme == .dark ? "Dark-Calendar-Filter" : "Light-Calendar-Filter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        // 필터 적용 중일 때 우측 상단 accent 닷으로 표식 — iOS 와 동일.
                        .overlay(alignment: .topTrailing) {
                            if viewModel.visibilityFilter.isFilterActive {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 6)
                                    .overlay(
                                        Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
                                    )
                                    .offset(x: 2, y: -2)
                            }
                        }
                }
                .help("표시할 소스 / 공유 캘린더 선택")
                .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                    MacCalendarFilterPopover(
                        filter: viewModel.visibilityFilter,
                        sharedCalendars: viewModel.mySharedCalendars
                    )
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewEventSheet = true
                } label: {
                    Label("새 일정", systemImage: "plus")
                }
                .help("선택된 날짜에 새 일정 추가")
            }
        }
        .onAppear {
            viewModel.loadEventsForCurrentMonth()
            viewModel.loadMySharedCalendars()
            installScrollSwipeMonitor()
        }
        .onDisappear {
            removeScrollSwipeMonitor()
        }
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
        .sheet(isPresented: $showNewEventSheet, onDismiss: { newEventTimeHint = nil }) {
            MacEventEditView(
                eventToEdit: nil,
                selectedDate: newEventTimeHint ?? viewModel.selectedDate,
                sharedCalendars: viewModel.mySharedCalendars,
                useTimeHint: newEventTimeHint != nil,
                onSave: { saved in
                    viewModel.saveDozyEvent(saved)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestRefresh)) { _ in
            viewModel.loadEventsForCurrentMonth()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestNewEvent)) { _ in
            showNewEventSheet = true
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { eventPendingDelete != nil },
                set: { if !$0 { eventPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: eventPendingDelete
        ) { event in
            if let dozy = viewModel.dozyEventsByID[event.id], dozy.recurrenceRule != "none" {
                Button("이 일정만 삭제", role: .destructive) {
                    viewModel.deleteThisOccurrence(dozy, date: event.startDate)
                    eventPendingDelete = nil
                }
                Button("이후 모든 일정 삭제", role: .destructive) {
                    viewModel.deleteFutureOccurrences(dozy, from: event.startDate)
                    eventPendingDelete = nil
                }
                Button("모든 반복 일정 삭제", role: .destructive) {
                    viewModel.deleteDozyEvent(dozy)
                    eventPendingDelete = nil
                }
                Button("취소", role: .cancel) { eventPendingDelete = nil }
            } else {
                Button("삭제", role: .destructive) {
                    if let dozy = viewModel.dozyEventsByID[event.id] {
                        viewModel.deleteDozyEvent(dozy)
                    }
                    eventPendingDelete = nil
                }
                Button("취소", role: .cancel) { eventPendingDelete = nil }
            }
        } message: { event in
            if let dozy = viewModel.dozyEventsByID[event.id], dozy.recurrenceRule != "none" {
                Text("삭제할 범위를 선택해주세요.")
            } else {
                Text("정말로 삭제하시겠습니까?")
            }
        }
    }

    private var deleteDialogTitle: String {
        guard let event = eventPendingDelete,
              let dozy = viewModel.dozyEventsByID[event.id]
        else { return "일정 삭제" }
        return dozy.recurrenceRule != "none" ? "반복 일정 삭제" : "일정 삭제"
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button {
                animatedGoToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Button {
                pickerYear = Calendar.current.component(.year, from: viewModel.currentMonth)
                pickerMonth = Calendar.current.component(.month, from: viewModel.currentMonth)
                showMonthPicker.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.monthTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 140, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showMonthPicker, arrowEdge: .bottom) {
                monthYearPicker
            }

            Button {
                animatedGoToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.rightArrow, modifiers: .command)

            Spacer()

            Picker("보기", selection: Binding(
                get: { viewModel.viewMode },
                set: { viewModel.setViewMode($0) }
            )) {
                ForEach(MacCalendarViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)

            Button("오늘") {
                viewModel.goToToday()
            }
            .buttonStyle(.bordered)
        }
    }

    // 주 뷰용 7일 배열 (일요일 시작)
    private func weekDates() -> [Date] {
        let cal = Calendar.current
        let start = MacCalendarViewModel.startOfWeek(for: viewModel.currentMonth)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// 주/일 뷰의 .id 바뀔 때 적용할 슬라이드 트랜지션
    private var weekDayTransition: AnyTransition {
        let isForward = viewModel.monthTransitionDirection >= 0
        return .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading),
            removal:   .move(edge: isForward ? .leading : .trailing)
        )
    }

    // MARK: - Month / Year Picker

    private var monthYearPicker: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Picker("", selection: $pickerYear) {
                    ForEach(yearRange, id: \.self) { y in
                        Text(String(format: "%d년", y)).tag(y)
                    }
                }
                .labelsHidden()
                .frame(width: 110)

                Picker("", selection: $pickerMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text("\(m)월").tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
            }

            HStack {
                Button("취소") {
                    showMonthPicker = false
                }
                Spacer()
                Button("이동") {
                    jumpToMonth(year: pickerYear, month: pickerMonth)
                    showMonthPicker = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 10)...(current + 10))
    }

    private func jumpToMonth(year: Int, month: Int) {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let newDate = Calendar.current.date(from: comps) else { return }
        viewModel.currentMonth = newDate
        viewModel.loadEventsForCurrentMonth()
    }

    /// 버튼/단축키로 월 이동 시 실시간 paging 애니메이션 재사용.
    /// spring response: 0.28 → 0.22 (snappier), damping 0.92 → 0.86 (덜 mushy).
    private static let pagingAnimation: Animation = .spring(response: 0.22, dampingFraction: 0.86)

    /// chevron 버튼 / 단축키. 월 모드는 MacMonthPagingScrollView 의 onChange 가
    /// 받아 scrollPosition 을 spring 으로 이동, 주/일 모드는 .id() + transition
    /// 이 슬라이드인 처리 — 양쪽 모두 withAnimation 감싸서 트리거.
    private func animatedGoToPreviousMonth() {
        withAnimation(Self.pagingAnimation) {
            viewModel.goToPreviousMonth()
        }
    }

    private func animatedGoToNextMonth() {
        withAnimation(Self.pagingAnimation) {
            viewModel.goToNextMonth()
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) { idx, day in
                Text(day)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        idx == 0 ? .red :
                        idx == 6 ? .blue : .secondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Paging Month Area (UIPageViewController 스타일)

    private var previousMonth: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: viewModel.currentMonth) ?? viewModel.currentMonth
    }

    private var nextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: viewModel.currentMonth) ?? viewModel.currentMonth
    }

    private var pagingMonthArea: some View {
        // SwiftUI ScrollView + .scrollTargetBehavior(.paging) 로 교체.
        // 트랙패드/Magic Mouse 가로 스크롤이 OS 레벨 paging 으로 처리되어 손가락
        // follow 가 frame-perfect, 이전 NSEvent monitor + liveOffset 60fps publish
        // 방식의 stutter 가 사라짐.
        MacMonthPagingScrollView(viewModel: viewModel) { month in
            monthGridView(for: month)
        }
        .clipped()
    }

    private func monthGridView(for month: Date) -> some View {
        let dates = visibleDates(for: month)
        return VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                let weekDates = Array(dates[(row * 7)..<(row * 7 + 7)])
                MacCalendarWeekRow(
                    weekDates: weekDates,
                    currentMonth: month,
                    selectedDate: viewModel.selectedDate,
                    eventsByDate: viewModel.eventsByDate,
                    onSelectDate: { viewModel.selectDate($0) },
                    onSelectEvent: { selectedEvent = $0 },
                    onCreateEvent: { date in
                        viewModel.selectDate(date)
                        showNewEventSheet = true
                    },
                    onGoToToday: { viewModel.goToToday() },
                    onEditEvent: handleEditEvent,
                    onDeleteEvent: handleDeleteEvent
                )
                .equatable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if row < 5 {
                    Divider()
                }
            }
        }
    }

    private func visibleDates(for month: Date) -> [Date] {
        let cal = Calendar.current
        guard let startOfMonth = cal.dateInterval(of: .month, for: month)?.start else { return [] }
        let weekday = cal.component(.weekday, from: startOfMonth)
        guard let startOfGrid = cal.date(byAdding: .day, value: -(weekday - 1), to: startOfMonth) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: startOfGrid) }
    }

    private func isInMonth(_ date: Date, month: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: month)
            && cal.component(.year, from: date) == cal.component(.year, from: month)
    }

    // MARK: - Event List

    private var eventListSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.selectedDateTitle)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                let events = viewModel.eventsForSelectedDate

                if events.isEmpty {
                    Button {
                        showNewEventSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("일정이 없습니다. 새로 추가해볼까요?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                } else {
                    ForEach(events) { event in
                        MacEventRow(
                            event: event,
                            isCompleted: viewModel.isCompleted(for: event, on: viewModel.selectedDate),
                            onToggleCompletion: event.isReadOnly ? nil : {
                                viewModel.toggleCompletion(for: event, on: viewModel.selectedDate)
                            },
                            onSelect: event.isReadOnly ? nil : { selectedEvent = event }
                        )
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Magic Mouse Horizontal Scroll (월 전환)

    /// Magic Mouse / 트랙패드의 가로 스크롤을 누적 델타로 모은 뒤 한 번에 commit.
    /// 라이브 프리뷰 (스크롤마다 liveOffset 업데이트) 를 빼서 60fps 의 SwiftUI
    /// 트리 invalidate 를 제거 — 무거운 grid 의 .equatable() 체크가 매 프레임
    /// 돌면서 발생하던 stutter 를 해소. 사용자 입장에선 스크롤 중엔 화면이
    /// 정지하다가 끝에 스냅 애니메이션으로 다음/이전 달로 넘어감.
    private func installScrollSwipeMonitor() {
        guard swipeState.monitor == nil else { return }
        let vm = viewModel
        let state = swipeState
        swipeState.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard state.isHovering else { return event }
            guard state.viewWidth > 0 else { return event }
            // 월 모드는 SwiftUI ScrollView 가 native paging 으로 처리 — monitor 가
            // 가로채면 안 됨. 주/일 모드만 기존 누적-델타 방식 사용.
            guard vm.viewMode != .month else { return event }

            // 관성 스크롤 무시
            guard event.momentumPhase == [] else { return event }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            // 가로 우세 스크롤만
            guard abs(dx) > abs(dy) * 1.2, abs(dx) > 0.1 else { return event }

            // SwiftUI 와 무관한 ivar 누적 — 트리 invalidate 안 함.
            state.pendingDeltaX += dx

            // phase 로 종료 감지하면 즉시 commit, 아니면 짧은 inactivity 후 fallback.
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                state.commitWork?.cancel()
                state.commitWork = nil
                commitSwipe(state: state, vm: vm)
            } else {
                state.commitWork?.cancel()
                let work = DispatchWorkItem {
                    commitSwipe(state: state, vm: vm)
                }
                state.commitWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07, execute: work)
            }

            return nil
        }
    }

    /// pendingDeltaX 임계값에 따라 다음/이전 달 commit. 라이브 프리뷰 없이 한 번에
    /// 슬라이드 애니메이션으로 넘김 — month 뷰는 liveOffset 으로 슬라이드, week/day 는
    /// VM 의 currentMonth 변경에 따른 transition 만 사용.
    private func commitSwipe(state: MonthSwipeState, vm: MacCalendarViewModel) {
        let width = state.viewWidth
        guard width > 0 else {
            state.pendingDeltaX = 0
            return
        }
        let anim: Animation = .spring(response: 0.28, dampingFraction: 0.92)
        let delta = state.pendingDeltaX
        state.pendingDeltaX = 0

        // 월 뷰 / 주·일 뷰 동일하게 동작 — 라이브 프리뷰 빠진 모델에선 차이 없음.
        let threshold: CGFloat = vm.viewMode == .month ? max(width * 0.12, 40) : 50

        if delta > threshold {
            // 오른쪽으로 스와이프 → 이전 달. 슬라이드 애니메이션으로 넘김.
            withAnimation(anim) {
                state.liveOffset = width
            } completion: {
                var txn = Transaction()
                txn.disablesAnimations = true
                withTransaction(txn) {
                    vm.goToPreviousMonth()
                    state.liveOffset = 0
                }
            }
        } else if delta < -threshold {
            withAnimation(anim) {
                state.liveOffset = -width
            } completion: {
                var txn = Transaction()
                txn.disablesAnimations = true
                withTransaction(txn) {
                    vm.goToNextMonth()
                    state.liveOffset = 0
                }
            }
        }
        // threshold 미만이면 아무 일도 안 함 (라이브 프리뷰 없으니 되돌릴 것도 없음).
    }

    private func removeScrollSwipeMonitor() {
        if let m = swipeState.monitor {
            NSEvent.removeMonitor(m)
            swipeState.monitor = nil
        }
        swipeState.commitWork?.cancel()
        swipeState.liveOffset = 0
        swipeState.isHovering = false
    }
}

// MARK: - MonthSwipeState

final class MonthSwipeState: ObservableObject {
    @Published var liveOffset: CGFloat = 0   // commit 시 슬라이드 애니메이션용 (스크롤 중엔 0 유지)
    /// 스크롤 중 누적되는 가로 델타. 라이브 프리뷰 없이 .ended/inactivity 시점에 threshold 비교용.
    /// SwiftUI 와 무관 (published 아님) — 스크롤 60fps 호출에도 view 트리 invalidate 안 됨.
    var pendingDeltaX: CGFloat = 0
    var isHovering: Bool = false
    var viewWidth: CGFloat = 0
    var monitor: Any?
    var commitWork: DispatchWorkItem?

    deinit {
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
        commitWork?.cancel()
    }
}
