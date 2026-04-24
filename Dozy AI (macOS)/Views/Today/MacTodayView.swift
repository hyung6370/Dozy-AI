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
    @EnvironmentObject private var authViewModel: MacAuthViewModel
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var showNewEventSheet = false

    @State private var memoText: String = ""
    @State private var editingMemoIndex: Int? = nil
    @State private var editingMemoText: String = ""
    @State private var showEditMemoAlert = false
    @State private var deletingMemoIndex: Int? = nil
    @State private var showDeleteMemoAlert = false

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
                } else {
                    if let summary = viewModel.dailySummary {
                        aiSummaryPreview(summary)
                    }
                    if !viewModel.todayEvents.isEmpty {
                        eventListSection
                    }
                    memoSection
                    if !viewModel.hasSummary {
                        aiGenerateButton
                    }
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
        // Detail sheet — 모든 편집이 인라인으로 이루어짐
        .sheet(item: $selectedEvent) { event in
            MacEventDetailView(
                event: event,
                dozyEvent: viewModel.dozyEventsByID[event.id],
                currentUserID: authViewModel.currentUser?.id ?? "",
                partnerDisplayName: nil,
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
        .alert("메모 수정", isPresented: $showEditMemoAlert) {
            TextField("메모", text: $editingMemoText)
            Button("저장") {
                if let index = editingMemoIndex {
                    viewModel.updateMemo(at: index, text: editingMemoText)
                }
                editingMemoIndex = nil
            }
            Button("취소", role: .cancel) { editingMemoIndex = nil }
        }
        .alert("메모 삭제", isPresented: $showDeleteMemoAlert) {
            Button("삭제", role: .destructive) {
                if let index = deletingMemoIndex {
                    viewModel.deleteMemo(at: index)
                }
                deletingMemoIndex = nil
            }
            Button("취소", role: .cancel) { deletingMemoIndex = nil }
        } message: {
            Text("정말로 삭제하시겠습니까?")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestRefresh)) { _ in
            viewModel.loadTodayData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestNewEvent)) { _ in
            showNewEventSheet = true
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
                ForEach(Array(summary.highlights.prefix(3).enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                        Text(h)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if !summary.nextActions.isEmpty {
                Divider().padding(.vertical, 2)
                ForEach(Array(summary.nextActions.prefix(3).enumerated()), id: \.offset) { _, action in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                            .padding(.top, 3)
                        Text(action)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.indigo.opacity(0.12), lineWidth: 1))
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default:        return .red
        }
    }

    // MARK: - Memo Section

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
                        Text("📝").font(.subheadline)
                        Text(memo)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
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
                    .lineLimit(1...4)
                    .onSubmit { submitMemo() }

                Button {
                    submitMemo()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
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
            viewModel.generateAISummary()
        } label: {
            HStack(spacing: 12) {
                if viewModel.isSummarizing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dozy 요약 생성")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(viewModel.isSummarizing
                         ? "Dozy가 분석 중입니다..."
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
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasData || viewModel.isSummarizing)
        .opacity(viewModel.hasData ? 1.0 : 0.5)
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
