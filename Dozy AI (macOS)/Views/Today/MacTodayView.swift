//
//  MacTodayView.swift
//  Dozy AI (macOS)
//
//  M4.4 — Today 뷰. iOS HomeView 의 헤더/Focus/Stats/Event List 블록을
//  macOS 디테일 패널 맥락에 맞게 재구성. Banner/AI 요약/메모/날씨는
//  다음 페이즈로 유보.
//

import SwiftUI

struct MacTodayView: View {
    @StateObject private var viewModel: MacHomeViewModel
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var eventToEdit: DozyEvent? = nil
    @State private var pendingEdit: DozyEvent? = nil
    @State private var showNewEventSheet = false

    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: MacHomeViewModel(container: container))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                focusCard
                statsRow

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if !viewModel.todayEvents.isEmpty {
                    eventListSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 720, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("오늘")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewEventSheet = true
                } label: {
                    Label("새 일정", systemImage: "plus")
                }
                .help("새 일정 추가")
            }
        }
        .onAppear {
            viewModel.loadTodayData()
        }
        .refreshable {
            viewModel.loadTodayData()
        }
        // Detail sheet — 편집 선택 시 dismiss 후 pendingEdit 을 통해 edit 시트로 전환
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
        // Edit sheet — 기존 이벤트 수정
        .sheet(item: $eventToEdit) { dozy in
            MacEventEditView(
                eventToEdit: dozy,
                selectedDate: dozy.startDate,
                onSave: { saved in
                    viewModel.saveDozyEvent(saved)
                }
            )
        }
        // New sheet — 새 일정 생성
        .sheet(isPresented: $showNewEventSheet) {
            MacEventEditView(
                eventToEdit: nil,
                selectedDate: Date(),
                onSave: { saved in
                    viewModel.saveDozyEvent(saved)
                }
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.todayDateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.greeting)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
    }

    // MARK: - Focus Card

    private var focusCard: some View {
        let currentEvent = viewModel.currentEvent
        let upcomingEvent = viewModel.upcomingEvent
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
                Button {
                    showNewEventSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Color.secondary)
                        Text("오늘 일정이 없습니다. 새로 추가해볼까요?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func timeUntilLabel(_ event: CalendarEvent) -> String {
        let now = Date()
        if event.startDate <= now { return "진행 중" }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        if minutes < 60 { return "\(minutes)분 후" }
        return "\(minutes / 60)시간 후"
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
            MacStatCard(
                value: "\(viewModel.eventCount)",
                label: "오늘 일정",
                icon: "calendar",
                color: .blue
            )
            MacStatCard(
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

            ForEach(viewModel.todayEvents) { event in
                MacEventRow(
                    event: event,
                    isCompleted: viewModel.completionsByEventID[event.id] == true
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedEvent = event
                }
            }
        }
    }
}

// MARK: - MacStatCard

private struct MacStatCard: View {
    let value: String
    let label: String
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
    }
}
