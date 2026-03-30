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
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    monthHeader
                    weekdayHeader
                    calendarGrid
                    Divider().padding(.horizontal)
                    eventListSection
                }
            }
            .navigationTitle("캘린더")
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
            .onAppear { viewModel.loadInitialData() }
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button { viewModel.previousMonth() } label: {
                Image(systemName: "chevron.left").fontWeight(.semibold)
            }
            
            Text(viewModel.currentMonthString)
                .font(.title2).fontWeight(.bold)
                .frame(maxWidth: .infinity)
            
            Button { viewModel.nextMonth() } label: {
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
    
    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(viewModel.daysInMonth.enumerated()), id: \.offset) { _, date in
                if let date {
                    DayCell(
                        date: date,
                        isSelected: viewModel.isSelected(date),
                        isToday: viewModel.isToday(date),
                        hasEvents: viewModel.hasEvents(on: date)
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
                    EventRow(event: event)
                        .padding(.horizontal)
                        .contextMenu {
                            if event.source == .dozy,
                               let dozyEvent = viewModel.dozyEventsForSelectedDate.first(where: { $0.id == event.id }) {
                                Button { viewModel.startEditingEvent(dozyEvent) } label: {
                                    Label("수정", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    viewModel.deleteEvent(dozyEvent)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 40)
    }
    
    private var selectedDateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M월 d일 (E)"
        fmt.locale = Locale(identifier: "ko_KR")
        return fmt.string(from: viewModel.selectedDate)
    }
}
