//
//  CalendarView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI
import Lottie

struct CalendarView: View {

    @ObservedObject var viewModel: CalendarViewModel
    @State private var showLegend = false
    @State private var longPressDate: Date? = nil
    @State private var showLongPressAlert = false
    @State private var pageIndex = 1
    @State private var isForward = true
    @State private var showMonthPicker = false
    @State private var pickerYear = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth = Calendar.current.component(.month, from: Date())
    @State private var showDatePicker = false
    @State private var pickerDate = Date()
    @State private var triggerScrollToList = false
    @Environment(\.scenePhase) private var scenePhase

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    viewModePicker
                    monthHeader
                    if viewModel.viewMode != .week {
                        weekdayHeader
                    }
                    panCalendarSection
                    Divider().padding(.horizontal)
                    if viewModel.viewMode == .day {
                        DayTimelineView(
                            events: viewModel.eventsForSelectedDate,
                            date: viewModel.selectedDate,
                            onTapEvent: { viewModel.showDetailForEventID($0) }
                        )
                        .padding(.horizontal)
                    } else {
                        eventListSection
                            .id("eventList")
                    }
                }
            }
            .refreshable {
                viewModel.refreshData()
            }
            .onChange(of: triggerScrollToList) { _, newVal in
                if newVal {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo("eventList", anchor: .top)
                    }
                    triggerScrollToList = false
                }
            }
            .navigationTitle("캘린더")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button { showLegend = true } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        Button { viewModel.startCreatingEvent() } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showLegend) {
                CalendarLegendView()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showMonthPicker) {
                MonthYearPickerView(
                    selectedYear: $pickerYear,
                    selectedMonth: $pickerMonth
                ) {
                    let cal = Calendar.current
                    var comps = DateComponents()
                    comps.year = pickerYear
                    comps.month = pickerMonth
                    comps.day = 1
                    if let target = cal.date(from: comps) {
                        isForward = target >= viewModel.currentMonth
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.jumpToMonth(year: pickerYear, month: pickerMonth)
                        }
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheetView(selectedDate: $pickerDate) {
                    isForward = pickerDate >= viewModel.selectedDate
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.selectDate(pickerDate)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showEventEdit) {
                EventEditView(
                    eventToEdit: viewModel.eventToEdit,
                    selectedDate: viewModel.selectedDate
                ) { event in
                    viewModel.saveEvent(event)
                }
            }
            .sheet(isPresented: $viewModel.showEventDetail) {
                eventDetailSheet
            }
            .sheet(isPresented: $viewModel.showCalendarEventEdit) {
                if let event = viewModel.calendarEventToEdit {
                    CalendarEventEditView(event: event) { edit in
                        viewModel.saveCalendarEvent(event, edit: edit)
                    }
                }
            }
            .onAppear { viewModel.loadInitialData() }
            .overlay {
                if viewModel.showSuccessAnimation {
                    LottieView(name: "success", loopMode: .playOnce, animationSpeed: 1.8) {
                        viewModel.showSuccessAnimation = false
                    }
                    .scaleEffect(0.22)
                    .allowsHitTesting(false)
                }
            }
            .alert(alertTitle, isPresented: $viewModel.showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    if let e = viewModel.pendingDeleteEvent {
                        viewModel.deleteEvent(e)
                    } else if let e = viewModel.pendingDeleteCalendarEvent {
                        viewModel.deleteCalendarEvent(e)
                    }
                    viewModel.pendingDeleteEvent = nil
                    viewModel.pendingDeleteCalendarEvent = nil
                }
                Button("취소", role: .cancel) {
                    viewModel.pendingDeleteEvent = nil
                    viewModel.pendingDeleteCalendarEvent = nil
                }
            } message: {
                Text(viewModel.pendingDeleteEvent?.recurrenceRule != "none" && viewModel.pendingDeleteEvent != nil
                     ? "모든 반복 일정이 함께 삭제됩니다. 정말 삭제하시겠습니까?"
                     : "정말로 삭제하시겠습니까?")
            }
            .alert("일정 삭제 완료", isPresented: $viewModel.showDeleteSuccess) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("일정이 성공적으로 삭제되었습니다.")
            }
            .alert("삭제 실패", isPresented: Binding(
                get: { viewModel.deleteErrorMessage != nil },
                set: { if !$0 { viewModel.deleteErrorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { viewModel.deleteErrorMessage = nil }
            } message: {
                Text(viewModel.deleteErrorMessage ?? "")
            }
            .alert("일정 생성", isPresented: $showLongPressAlert, actions: longPressAlertActions, message: longPressAlertMessage)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    showLegend = false
                    showMonthPicker = false
                    showDatePicker = false
                    viewModel.showEventDetail = false
                    viewModel.showEventEdit = false
                    viewModel.showCalendarEventEdit = false
                }
            }
            } // ScrollViewReader
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private var eventDetailSheet: some View {
        if let event = viewModel.detailEvent {
            let dozyEvent = viewModel.dozyEventsForSelectedDate.first(where: { $0.id == event.id })
                ?? viewModel.dozyEventsByID[event.id]
            EventDetailView(
                event: event,
                dozyEvent: dozyEvent,
                onEdit: { dozyEvent in
                    viewModel.startEditingEvent(dozyEvent)
                },
                onDelete: { dozyEvent in
                    viewModel.requestDelete(event)
                },
                onDeleteThisOnly: { dozyEvent, date in
                    viewModel.deleteThisOccurrence(dozyEvent, date: date)
                },
                onDeleteFutureEvents: { dozyEvent, date in
                    viewModel.deleteFutureOccurrences(dozyEvent, from: date)
                },
                onEditCalendar: { viewModel.startEditingCalendarEvent($0) },
                onDeleteCalendar: { viewModel.deleteCalendarEvent($0) },
                onSaveMemos: { dozyEvent in
                    viewModel.saveMemos(for: dozyEvent)
                },
                onUpdateDisplaySettings: { event, priority, isPinned, category in
                    viewModel.updateDisplaySettings(for: event, priority: priority, isPinned: isPinned, category: category)
                }
            )
        }
    }

    // MARK: - Month Header

    private var isOnToday: Bool {
        let cal = Calendar.current
        switch viewModel.viewMode {
        case .month:
            return cal.isDate(viewModel.currentMonth, equalTo: Date(), toGranularity: .month)
        case .week:
            return viewModel.currentWeekDates.contains { cal.isDateInToday($0) }
        case .day:
            return cal.isDateInToday(viewModel.selectedDate)
        }
    }

    private var monthHeader: some View {
        HStack {
            HStack(spacing: 16) {
                Button {
                    isForward = viewModel.selectedDate < Date()
                    if viewModel.viewMode == .month {
                        let cal = Calendar.current
                        let todayStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
                        isForward = viewModel.currentMonth < todayStart
                        viewModel.setCurrentMonth(Date())
                    }
                    viewModel.selectDate(Date())
                } label: {
                    Image(systemName: "arrow.uturn.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                .opacity(isOnToday ? 0 : 1)
                .disabled(isOnToday)

                Button {
                    isForward = false
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.previousPeriod() }
                } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
            }

            Group {
                if viewModel.viewMode == .month {
                    Button {
                        let cal = Calendar.current
                        pickerYear = cal.component(.year, from: viewModel.currentMonth)
                        pickerMonth = cal.component(.month, from: viewModel.currentMonth)
                        showMonthPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.currentPeriodString)
                                .font(.title2).fontWeight(.bold)
                            Image(systemName: "chevron.down")
                                .font(.caption).fontWeight(.semibold)
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        pickerDate = viewModel.selectedDate
                        showDatePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.currentPeriodString)
                                .font(.title2).fontWeight(.bold)
                            Image(systemName: "chevron.down")
                                .font(.caption).fontWeight(.semibold)
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                isForward = true
                withAnimation(.easeInOut(duration: 0.3)) { viewModel.nextPeriod() }
            } label: {
                Image(systemName: "chevron.right").fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Weekday Header
    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(day == "일" ? .red : day == "토" ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Calendar Grid

    private var monthGrid: some View {
        monthGridView(for: viewModel.currentMonth)
    }

    private func monthGridView(for month: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.weeksFor(month: month).enumerated()), id: \.offset) { weekIndex, week in
                MonthWeekRowView(
                    weekDates: week,
                    layouts: viewModel.weekLayouts[
                        Calendar.current.startOfDay(for: viewModel.weekStartDate(weekIndex: weekIndex, month: month))
                    ] ?? [],
                    selectedDate: viewModel.selectedDate,
                    isToday: { viewModel.isToday($0) },
                    isSelected: { viewModel.isSelected($0) },
                    isInMonth: { date in
                        let cal = Calendar.current
                        return cal.component(.month, from: date) == cal.component(.month, from: month)
                            && cal.component(.year, from: date) == cal.component(.year, from: month)
                    },
                    onSelect: { viewModel.selectDate($0) },
                    onLongPress: { date in
                        longPressDate = date
                        showLongPressAlert = true
                    },
                    onTapEvent: { viewModel.showDetailForEventID($0) },
                    onOverflowTap: { date in
                        viewModel.selectDate(date)
                        triggerScrollToList = true
                    }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MonthWeekRowView.totalH = 42 + 3*(20+2) + 18 = 126pt
    private var monthGridHeight: CGFloat {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: viewModel.currentMonth))!
        let weekday = cal.component(.weekday, from: first) - 1
        let dayCount = cal.range(of: .day, in: .month, for: viewModel.currentMonth)!.count
        let weekCount = (weekday + dayCount + 6) / 7
        return CGFloat(weekCount) * 126 + 8
    }

    @ViewBuilder
    private var panCalendarSection: some View {
        if viewModel.viewMode == .month {
            MonthPageViewController(
                currentMonth: viewModel.currentMonth,
                weekLayouts: viewModel.weekLayouts,
                selectedDate: viewModel.selectedDate,
                isToday: { viewModel.isToday($0) },
                isSelected: { viewModel.isSelected($0) },
                onSelect: { viewModel.selectDate($0) },
                onLongPress: { date in longPressDate = date; showLongPressAlert = true },
                onTapEvent: { viewModel.showDetailForEventID($0) },
                onOverflowTap: { date in
                    viewModel.selectDate(date)
                    triggerScrollToList = true
                },
                onMonthChanged: { newMonth in
                    isForward = newMonth > viewModel.currentMonth
                    viewModel.setCurrentMonth(newMonth)
                }
            )
            .frame(height: monthGridHeight)
            .animation(.easeInOut(duration: 0.3), value: monthGridHeight)
        } else {
            ZStack {
                calendarGrid
                    .id(viewModel.currentPeriodString)
                    .transition(.asymmetric(
                        insertion: .move(edge: isForward ? .trailing : .leading),
                        removal: .move(edge: isForward ? .leading : .trailing)
                    ))
            }
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < -30 {
                            isForward = true
                            withAnimation(.easeInOut(duration: 0.3)) { viewModel.nextPeriod() }
                        } else if value.translation.width > 30 {
                            isForward = false
                            withAnimation(.easeInOut(duration: 0.3)) { viewModel.previousPeriod() }
                        }
                    }
            )
        }
    }

    private var calendarGrid: some View {
        Group {
            switch viewModel.viewMode {
            case .month:
                monthGrid
            case .week:
                WeekGridView(
                    weekDates: viewModel.currentWeekDates,
                    selectedDate: viewModel.selectedDate,
                    eventBars: { viewModel.eventBars(for: $0) },
                    onSelectDate: { viewModel.selectDate($0) }
                )
            case .day:
                EmptyView()
            }
        }
    }
    
    // MARK: - Event List
    
    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(
                    title: selectedDateLabel,
                    icon: "list.bullet"
                )
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
            } else if viewModel.eventsForSelectedDate.isEmpty {
                Text("일정이 없습니다")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            } else {
                ForEach(viewModel.eventsForSelectedDate) { event in
                    EventRow(
                        event: event,
                        isCompleted: viewModel.isCompleted(for: event),
                        onToggle: { viewModel.toggleCompletion(for: event) }
                    )
                    .padding(.horizontal)
                    .onTapGesture {
                        viewModel.showDetail(for: event)
                    }
                    .contextMenu { eventContextMenu(for: event) }
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 40)
    }
    
    @ViewBuilder
    private func eventContextMenu(for event: CalendarEvent) -> some View {
        if let dozyEvent = viewModel.dozyEvent(for: event) {
            Button { viewModel.startEditingEvent(dozyEvent) } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.requestDelete(event)
            } label: {
                Label(dozyEvent.recurrenceRule != "none" ? "반복 일정 삭제" : "삭제", systemImage: "trash")
            }
        } else if event.source == .apple || event.source == .google {
            Button { viewModel.startEditingCalendarEvent(event) } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.requestDelete(event)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }

        Divider()

        // 핀 토글
        Button {
            viewModel.updateDisplaySettings(for: event, priority: event.priority, isPinned: !event.isPinned)
        } label: {
            Label(event.isPinned ? "고정 해제" : "상단 고정",
                  systemImage: event.isPinned ? "pin.slash" : "pin")
        }

        // 우선순위 서브메뉴
        Menu("우선순위") {
            Button("없음")    { viewModel.updateDisplaySettings(for: event, priority: 0, isPinned: event.isPinned) }
            Button("높음 🔴") { viewModel.updateDisplaySettings(for: event, priority: 1, isPinned: event.isPinned) }
            Button("중간 🟡") { viewModel.updateDisplaySettings(for: event, priority: 2, isPinned: event.isPinned) }
            Button("낮음 🔵") { viewModel.updateDisplaySettings(for: event, priority: 3, isPinned: event.isPinned) }
        }
    }

    @ViewBuilder
    private func longPressAlertActions() -> some View {
        Button("생성") {
            if let date = longPressDate {
                viewModel.selectDate(date)
                viewModel.startCreatingEvent()
            }
            longPressDate = nil
        }
        Button("취소", role: .cancel) { longPressDate = nil }
    }

    @ViewBuilder
    private func longPressAlertMessage() -> some View {
        if let date = longPressDate {
            let formatter = DateFormatter()
            let _ = { formatter.locale = Locale(identifier: "ko_KR"); formatter.dateFormat = "M월 d일(E)" }()
            Text("\(formatter.string(from: date))에 일정을 생성하시겠습니까?")
        }
    }

    private var alertTitle: String {
        if let e = viewModel.pendingDeleteEvent {
            return e.recurrenceRule != "none" ? "반복 일정 삭제" : "일정 삭제"
        }
        return "일정 삭제"
    }

    private var selectedDateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M월 d일 (E)"
        fmt.locale = Locale(identifier: "ko_KR")
        return fmt.string(from: viewModel.selectedDate)
    }
    
    private var viewModePicker: some View {
        Picker("뷰 모드", selection: $viewModel.viewMode) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

// MARK: - DatePickerSheetView

private struct DatePickerSheetView: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
            .navigationTitle("날짜 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("이동") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(430)])
    }
}
