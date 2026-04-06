//
//  HomeView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import SwiftUI

struct HomeView: View {

    private let container: DependencyContainer
    @StateObject private var viewModel: HomeViewModel
    @State private var memoText = ""
    @State private var showSummarySheet = false
    @State private var editingMemoIndex: Int? = nil
    @State private var editingMemoText = ""
    @State private var showEditMemoAlert = false
    @State private var deletingMemoIndex: Int? = nil
    @State private var showDeleteMemoAlert = false

    init(container: DependencyContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: HomeViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    bannerSection
                    focusCard
                    statsRow

                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        if !viewModel.todayEvents.isEmpty {
                            eventListSection
                        }
                        if let summary = viewModel.dailySummary {
                            aiSummaryPreview(summary)
                        }
                        memoSection
                        aiGenerateButton
                        if let log = viewModel.todayLog, !log.aiSummary.isEmpty {
                            aiSummaryDetail(log)
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
            .refreshable { viewModel.loadTodayData() }
            .onAppear { viewModel.loadTodayData() }
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
        .sheet(isPresented: $showSummarySheet) {
                DailySummaryView(
                    generateSummaryUseCase: container.generateDailySummaryUseCase,
                    fetchRecentLogsUseCase: container.fetchRecentLogsUseCase,
                    events: viewModel.todayEvents,
                    completedTasks: viewModel.completedTasks,
                    pendingTasks: viewModel.pendingTasks,
                    memos: viewModel.todayLog?.memos ?? []
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(viewModel.todayDateString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "좋은 아침이에요 ☀️"
        case 12..<17: return "좋은 오후예요 🌤️"
        case 17..<21: return "좋은 저녁이에요 🌙"
        default:      return "안녕하세요 🌟"
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        BannerView(items: BannerItem.placeholders, interval: 4)
    }

    // MARK: - Focus Card

    private var focusCard: some View {
        let nextEvent = viewModel.todayEvents.first(where: { $0.endDate > Date() })

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("오늘의 포커스")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)

            if let event = nextEvent {
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
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    Text(viewModel.todayEvents.isEmpty ? "오늘 일정이 없어요" : "오늘 일정을 모두 마쳤어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
            HomeStatCard(value: "\(viewModel.eventCount)", label: "오늘 일정", icon: "calendar", color: .blue)
            HomeStatCard(
                value: "\(viewModel.completedCount)/\(viewModel.completedCount + viewModel.pendingCount)",
                label: "할일 완료",
                icon: "checkmark.circle.fill",
                color: .green
            )
            HomeStatCard(value: "\(viewModel.pendingCount)", label: "남은 할일", icon: "circle.dotted", color: .orange)
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
                EventRow(event: event)
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
                Label("AI 요약", systemImage: "sparkles")
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
        .onTapGesture { showSummarySheet = true }
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
                        Text("📝").font(.subheadline)
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

            HStack(spacing: 10) {
                TextField("메모를 남겨보세요", text: $memoText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitMemo() }

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

    // MARK: - AI Generate Button

    private var aiGenerateButton: some View {
        Button {
            if viewModel.hasSummary { showSummarySheet = true }
            else { viewModel.generateAISummary() }
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
                    Text(viewModel.hasSummary ? "AI 업무 요약 보기" : "AI 업무 요약 생성")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(viewModel.isSummarizing
                         ? "AI가 분석 중입니다..."
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
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasData || viewModel.isSummarizing)
        .opacity(viewModel.hasData ? 1.0 : 0.5)
    }

    // MARK: - AI Summary Detail

    private func aiSummaryDetail(_ log: WorkLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 업무 요약")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text(log.aiSummary)
                    .font(.subheadline)
                    .lineSpacing(4)

                if !log.highlights.isEmpty {
                    Divider()
                    Text("핵심 하이라이트")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(log.highlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "star.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                if !log.nextActions.isEmpty {
                    Divider()
                    Text("추천 다음 할 일")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(log.nextActions, id: \.self) { action in
                        Label(action, systemImage: "arrow.right.circle")
                            .font(.caption).foregroundStyle(.blue)
                    }
                }
            }
            .padding(14)
            .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - HomeStatCard

private struct HomeStatCard: View {
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

#Preview {
    HomeView(container: DependencyContainer())
}
