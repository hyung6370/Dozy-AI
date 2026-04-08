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

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    viewModePicker
                    monthHeader
                    if viewModel.viewMode != .week {
                        weekdayHeader
                    }
                    calendarGrid
                        .gesture(
                            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                                .onEnded { value in
                                    if value.translation.width > 0 {
                                        viewModel.previousPeriod()
                                    } else {
                                        viewModel.nextPeriod()
                                    }
                                }
                        )
                    Divider().padding(.horizontal)
                    if viewModel.viewMode == .day {
                        DayTimelineView(
                            events: viewModel.eventsForSelectedDate,
                            date: viewModel.selectedDate
                        )
                        .padding(.horizontal)
                    } else {
                        eventListSection
                    }
                }
            }
            .refreshable {
                viewModel.refreshData()
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
                onEditCalendar: { viewModel.startEditingCalendarEvent($0) },
                onDeleteCalendar: { viewModel.deleteCalendarEvent($0) },
                onSaveMemos: { dozyEvent in
                    viewModel.saveMemos(for: dozyEvent)
                },
                onUpdateDisplaySettings: { event, priority, isPinned in
                    viewModel.updateDisplaySettings(for: event, priority: priority, isPinned: isPinned)
                }
            )
        }
    }

    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button { viewModel.previousPeriod() } label: {
                Image(systemName: "chevron.left").fontWeight(.semibold)
            }
            
            Text(viewModel.currentPeriodString)
                .font(.title2).fontWeight(.bold)
                .frame(maxWidth: .infinity)
            
            Button { viewModel.nextPeriod() } label: {
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
        .padding(.bottom, 8)
    }
    
    // MARK: - Calendar Grid
    
    private var monthGrid: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.weeksInMonth.enumerated()), id: \.offset) { weekIndex, week in
                MonthWeekRowView(
                    weekDates: week,
                    layouts: viewModel.weekLayouts[
                        Calendar.current.startOfDay(for: viewModel.weekStart(for: weekIndex))
                    ] ?? [],
                    selectedDate: viewModel.selectedDate,
                    isToday: { viewModel.isToday($0) },
                    isSelected: { viewModel.isSelected($0) },
                    onSelect: { viewModel.selectDate($0) },
                    onTapEvent: { viewModel.showDetailForEventID($0) }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
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
