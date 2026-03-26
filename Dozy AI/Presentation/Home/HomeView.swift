//
//  HomeView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//
//  [Clean Architecture - MVVM]
//  View는 ViewModel의 상태를 바인딩하고 사용자 이벤트를 ViewModel에 전달합니다.
//  DependencyContainer는 init에서 받아 저장합니다.
//  @EnvironmentObject는 사용하지 않습니다 (명시적 주입이 더 명확합니다).

import SwiftUI

struct HomeView: View {

    private let container: DependencyContainer
    @StateObject private var viewModel: HomeViewModel
    @State private var memoText = ""
    @State private var showSummarySheet = false

    // MARK: - Init

    init(container: DependencyContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: HomeViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    headerSection

                    if viewModel.isLoading {
                        loadingSection
                    } else if let error = viewModel.errorMessage {
                        errorSection(error)
                    } else {
                        summaryCard
                        aiGenerateButton

                        if let summary = viewModel.dailySummary {
                            aiSummaryPreview(summary)
                        }

                        if !viewModel.todayEvents.isEmpty {
                            eventListSection
                        }

                        if !viewModel.completedTasks.isEmpty {
                            completedTaskSection
                        }

                        if !viewModel.pendingTasks.isEmpty {
                            pendingTaskSection
                        }

                        memoSection

                        if let log = viewModel.todayLog, !log.aiSummary.isEmpty {
                            aiSummarySection(log)
                        }

                        if !viewModel.recentLogs.isEmpty {
                            recentLogsSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dozy AI")
            .refreshable {
                viewModel.loadTodayData()
            }
            .onAppear {
                viewModel.loadTodayData()
            }
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
}

// MARK: - Header

private extension HomeView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.todayDateString)
                .font(.title2)
                .fontWeight(.bold)
            Text("오늘 하루를 정리해드릴게요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Loading & Error

private extension HomeView {

    var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("데이터를 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }

    func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                viewModel.loadTodayData()
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }
}

// MARK: - Summary Card

private extension HomeView {

    var summaryCard: some View {
        HStack(spacing: 0) {
            StatBadge(icon: "calendar", value: "\(viewModel.eventCount)", label: "일정", color: .blue)
            Divider().frame(height: 40)
            StatBadge(icon: "checkmark.circle.fill", value: "\(viewModel.completedCount)", label: "완료", color: .green)
            Divider().frame(height: 40)
            StatBadge(icon: "clock", value: "\(viewModel.pendingCount)", label: "남은 할 일", color: .orange)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AI Generate Button

private extension HomeView {

    var aiGenerateButton: some View {
        Button {
            if viewModel.hasSummary {
                showSummarySheet = true
            } else {
                viewModel.generateAISummary()
            }
        } label: {
            HStack(spacing: 12) {
                if viewModel.isSummarizing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: viewModel.hasSummary ? "brain.head.profile" : "sparkles")
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.hasSummary ? "AI 업무 요약 보기" : "AI 업무 요약 생성")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(viewModel.isSummarizing
                         ? "AI가 분석 중입니다..."
                         : viewModel.hasSummary
                         ? "생산성 점수: \(viewModel.scorePercentage)점"
                         : "오늘 하루를 AI가 분석합니다")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                LinearGradient(
                    colors: viewModel.hasSummary ? [.indigo, .purple] : [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!viewModel.hasData || viewModel.isSummarizing)
        .opacity(viewModel.hasData ? 1.0 : 0.5)
    }
}

// MARK: - AI Summary Inline Preview

private extension HomeView {

    func aiSummaryPreview(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 요약", systemImage: "brain.head.profile")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo)

                Spacer()

                Text("\(viewModel.scorePercentage)점")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor(summary.productivityScore).opacity(0.15))
                    .foregroundStyle(scoreColor(summary.productivityScore))
                    .clipShape(Capsule())
            }

            Text(summary.summaryText)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if !summary.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.indigo.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.indigo.opacity(0.12), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { showSummarySheet = true }
    }

    func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default:        return .red
        }
    }
}

// MARK: - Event List

private extension HomeView {

    var eventListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "오늘 일정", icon: "calendar")
            ForEach(viewModel.todayEvents) { event in
                EventRow(event: event)
            }
        }
    }
}

// MARK: - Completed Tasks

private extension HomeView {

    var completedTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "완료한 할 일", icon: "checkmark.circle.fill")
            ForEach(viewModel.completedTasks) { task in
                TaskRow(task: task, isCompleted: true)
            }
        }
    }
}

// MARK: - Pending Tasks

private extension HomeView {

    var pendingTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "남은 할 일", icon: "clock")

            ForEach(viewModel.pendingTasks.prefix(5)) { task in
                TaskRow(task: task, isCompleted: false)
            }

            if viewModel.pendingTasks.count > 5 {
                Text("외 \(viewModel.pendingTasks.count - 5)건 더 있음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Memo

private extension HomeView {

    var memoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "메모", icon: "square.and.pencil")

            if let log = viewModel.todayLog, !log.memos.isEmpty {
                ForEach(Array(log.memos.enumerated()), id: \.offset) { _, memo in
                    HStack(alignment: .top, spacing: 8) {
                        Text("📝").font(.subheadline)
                        Text(memo)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 10) {
                TextField("오늘 메모를 남겨보세요...", text: $memoText)
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
}

// MARK: - AI Summary Detail (WorkLog에 저장된 요약 표시)

private extension HomeView {

    func aiSummarySection(_ log: WorkLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "AI 업무 요약", icon: "brain.head.profile")

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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.blue.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Recent Logs

private extension HomeView {

    var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "최근 기록", icon: "clock.arrow.circlepath")
            ForEach(viewModel.recentLogs) { log in
                RecentLogRow(log: log)
            }
        }
    }
}

#Preview {
    HomeView(container: DependencyContainer())
}
