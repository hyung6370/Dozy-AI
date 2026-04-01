//
//  CalendarView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI

struct CalendarView: View {
    
    @StateObject private var viewModel: CalendarViewModel
    
    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: CalendarViewModel(container: container))
    }
    
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    BannerView(items: BannerItem.placeholders)
                        .padding(.horizontal)
                        .padding(.vertical, 15)
                    viewModePicker
                    monthHeader
                    weekdayHeader
                    calendarGrid
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
            .navigationTitle("캘린더")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.startCreatingEvent() } label: {
                        Image(systemName: "plus")
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
                if let event = viewModel.detailEvent {
                    EventDetailView(
                        event: event,
                        dozyEvent: viewModel.dozyEventsByID[event.id],
                        onEdit: { (dozyEvent: DozyEvent) in
                            viewModel.startEditingEvent(dozyEvent)
                        },
                        onDelete: { (dozyEvent: DozyEvent) in
                            viewModel.requestDelete(dozyEvent)
                        }
                    )
                }
            }
            .onAppear { viewModel.loadInitialData() }
            .alert(
                viewModel.pendingDeleteEvent?.recurrenceRule != "none" ? "반복 일정 삭제" : "일정 삭제",
                isPresented: $viewModel.showDeleteAlert
            ) {
                Button("삭제", role: .destructive) {
                    if let e = viewModel.pendingDeleteEvent { viewModel.deleteEvent(e) }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text(viewModel.pendingDeleteEvent?.recurrenceRule != "none"
                     ? "모든 반복 일정이 함께 삭제됩니다. 정말 삭제하시겠습니까?"
                     : "정말로 삭제하시겠습니까?")
            }
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
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(viewModel.daysInMonth.enumerated()), id: \.offset) { _, date in
                if let date {
                    DayCell(
                        date: date,
                        isSelected: viewModel.isSelected(date),
                        isToday: viewModel.isToday(date),
                        eventBars: viewModel.eventBars(for: date)
                    ) {
                        viewModel.selectDate(date)
                    }
                } else {
                    Color.clear.frame(height: 50)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
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
                        isCompleted: viewModel.dozyEvent(for: event)?.isCompleted ?? false,
                        onToggle: event.source == .dozy ? {
                            if let dozyEvent = viewModel.dozyEvent(for: event) {
                                viewModel.toggleCompletion(for: dozyEvent)
                            }
                        } : nil
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
                viewModel.requestDelete(dozyEvent)
            } label: {
                Label(dozyEvent.recurrenceRule != "none" ? "반복 일정 삭제" : "삭제", systemImage: "trash")
            }
        }
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
