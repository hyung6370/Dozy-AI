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

struct MacCalendarView: View {
    @StateObject private var viewModel: MacCalendarViewModel
    @StateObject private var swipeState = MonthSwipeState()
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var eventToEdit: DozyEvent? = nil
    @State private var pendingEdit: DozyEvent? = nil
    @State private var showNewEventSheet = false
    @State private var showMonthPicker = false
    @State private var pickerYear = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth = Calendar.current.component(.month, from: Date())

    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: MacCalendarViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            weekdayHeader

            Divider()

            pagingMonthArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            eventListSection
                .frame(height: 180)
        }
        .navigationTitle("캘린더")
        .toolbar {
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
            installScrollSwipeMonitor()
        }
        .onDisappear {
            removeScrollSwipeMonitor()
        }
        .sheet(item: $selectedEvent, onDismiss: {
            if let pending = pendingEdit {
                eventToEdit = pending
                pendingEdit = nil
            }
        }) { event in
            MacEventDetailView(
                event: event,
                dozyEvent: viewModel.dozyEventsByID[event.id],
                onEdit: { dozy in
                    pendingEdit = dozy
                    selectedEvent = nil
                },
                onDelete: { dozy in
                    viewModel.deleteDozyEvent(dozy)
                    selectedEvent = nil
                }
            )
        }
        .sheet(item: $eventToEdit) { dozy in
            MacEventEditView(
                eventToEdit: dozy,
                selectedDate: dozy.startDate,
                onSave: { saved in
                    viewModel.saveDozyEvent(saved)
                }
            )
        }
        .sheet(isPresented: $showNewEventSheet) {
            MacEventEditView(
                eventToEdit: nil,
                selectedDate: viewModel.selectedDate,
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

            Button("오늘") {
                viewModel.goToToday()
            }
            .buttonStyle(.bordered)
        }
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
    private func animatedGoToPreviousMonth() {
        let width = swipeState.viewWidth
        guard width > 0 else { viewModel.goToPreviousMonth(); return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            swipeState.liveOffset = width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.37) {
            var txn = Transaction()
            txn.disablesAnimations = true
            withTransaction(txn) {
                viewModel.goToPreviousMonth()
                swipeState.liveOffset = 0
            }
        }
    }

    private func animatedGoToNextMonth() {
        let width = swipeState.viewWidth
        guard width > 0 else { viewModel.goToNextMonth(); return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            swipeState.liveOffset = -width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.37) {
            var txn = Transaction()
            txn.disablesAnimations = true
            withTransaction(txn) {
                viewModel.goToNextMonth()
                swipeState.liveOffset = 0
            }
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
        GeometryReader { geo in
            HStack(spacing: 0) {
                monthGridView(for: previousMonth).frame(width: geo.size.width)
                monthGridView(for: viewModel.currentMonth).frame(width: geo.size.width)
                monthGridView(for: nextMonth).frame(width: geo.size.width)
            }
            .offset(x: -geo.size.width + swipeState.liveOffset)
            .onAppear { swipeState.viewWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, newWidth in
                swipeState.viewWidth = newWidth
            }
            .onContinuousHover { phase in
                switch phase {
                case .active: swipeState.isHovering = true
                case .ended:  swipeState.isHovering = false
                }
            }
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
                    }
                )
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
                            isCompleted: viewModel.completionsByID[event.id] == true
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEvent = event
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Magic Mouse Horizontal Scroll (월 전환)

    /// Magic Mouse / 트랙패드의 가로 스크롤을 실시간 offset 으로 변환.
    /// 150ms 동안 이벤트가 없으면 snap (임계값 초과 → 이전/다음 월, 아니면 복귀).
    private func installScrollSwipeMonitor() {
        guard swipeState.monitor == nil else { return }
        let vm = viewModel
        let state = swipeState
        swipeState.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard state.isHovering else { return event }
            guard state.viewWidth > 0 else { return event }

            // 관성 스크롤 무시
            guard event.momentumPhase == [] else { return event }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            // 가로 우세 스크롤만
            guard abs(dx) > abs(dy) * 1.2, abs(dx) > 0.1 else { return event }

            // 실시간 offset 누적 (애니메이션 없이 즉시 반영)
            var txn = Transaction()
            txn.disablesAnimations = true
            withTransaction(txn) {
                state.liveOffset = max(-state.viewWidth, min(state.viewWidth, state.liveOffset + dx))
            }

            // 이벤트 멈춤 감지 → snap
            state.commitWork?.cancel()
            let work = DispatchWorkItem {
                commitSwipe(state: state, vm: vm)
            }
            state.commitWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)

            return nil
        }
    }

    /// liveOffset 임계값에 따라 스냅. 애니메이션 완료 후 currentMonth 업데이트 + offset 리셋.
    private func commitSwipe(state: MonthSwipeState, vm: MacCalendarViewModel) {
        let width = state.viewWidth
        guard width > 0 else { return }
        let threshold = width * 0.12
        let springDuration: TimeInterval = 0.32

        if state.liveOffset > threshold {
            // 이전 월로
            withAnimation(.spring(response: springDuration, dampingFraction: 0.88)) {
                state.liveOffset = width
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + springDuration + 0.02) {
                var txn = Transaction()
                txn.disablesAnimations = true
                withTransaction(txn) {
                    vm.goToPreviousMonth()
                    state.liveOffset = 0
                }
            }
        } else if state.liveOffset < -threshold {
            // 다음 월로
            withAnimation(.spring(response: springDuration, dampingFraction: 0.88)) {
                state.liveOffset = -width
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + springDuration + 0.02) {
                var txn = Transaction()
                txn.disablesAnimations = true
                withTransaction(txn) {
                    vm.goToNextMonth()
                    state.liveOffset = 0
                }
            }
        } else {
            // 임계값 미달 → 원위치로 복귀
            withAnimation(.spring(response: springDuration, dampingFraction: 0.88)) {
                state.liveOffset = 0
            }
        }
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
    @Published var liveOffset: CGFloat = 0   // 현재 drag 누적 오프셋 (양수: 오른쪽 = 이전 월 peek)
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
