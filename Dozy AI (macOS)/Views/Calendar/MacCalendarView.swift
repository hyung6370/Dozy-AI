//
//  MacCalendarView.swift
//  Dozy AI (macOS)
//
//  M4.5 — 월별 캘린더 뷰. 6주×7일 그리드 + 선택된 날짜의 이벤트 리스트.
//  이벤트 클릭 → MacEventDetailView, "+" → MacEventEditView.
//

import SwiftUI

struct MacCalendarView: View {
    @StateObject private var viewModel: MacCalendarViewModel
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var eventToEdit: DozyEvent? = nil
    @State private var pendingEdit: DozyEvent? = nil
    @State private var showNewEventSheet = false

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

            monthGrid
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
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Text(viewModel.monthTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(minWidth: 140, alignment: .center)

            Button {
                viewModel.goToNextMonth()
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

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) { idx, day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        idx == 0 ? .red :
                        idx == 6 ? .blue : .secondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Month Grid

    private var monthGrid: some View {
        let dates = visibleDates()
        return VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        let date = dates[idx]
                        MacCalendarDayCell(
                            date: date,
                            isInCurrentMonth: isInCurrentMonth(date),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            eventColors: viewModel.eventsByDate[Calendar.current.startOfDay(for: date)]?
                                .prefix(4)
                                .map { $0.calendarColorHex } ?? []
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            viewModel.selectDate(date)
                        }

                        if col < 6 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if row < 5 {
                    Divider()
                }
            }
        }
    }

    private func visibleDates() -> [Date] {
        let cal = Calendar.current
        guard let startOfMonth = cal.dateInterval(of: .month, for: viewModel.currentMonth)?.start else { return [] }
        let weekday = cal.component(.weekday, from: startOfMonth)
        guard let startOfGrid = cal.date(byAdding: .day, value: -(weekday - 1), to: startOfMonth) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: startOfGrid) }
    }

    private func isInCurrentMonth(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: viewModel.currentMonth)
            && cal.component(.year, from: date) == cal.component(.year, from: viewModel.currentMonth)
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
}
