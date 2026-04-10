//
//  DailySummaryView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - MVVM]
//  View는 UseCase를 직접 받아 ViewModel을 초기화합니다.
//  DependencyContainer 전체를 참조하지 않습니다.

import SwiftUI

struct DailySummaryView: View {

    @StateObject private var viewModel: DailySummaryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAction: RecommendedAction? = nil

    init(
        generateSummaryUseCase: GenerateDailySummaryUseCase,
        fetchRecentLogsUseCase: FetchRecentLogsUseCase,
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String],
        completedEventCount: Int = 0
    ) {
        let vm = DailySummaryViewModel(
            generateSummaryUseCase: generateSummaryUseCase,
            fetchRecentLogsUseCase: fetchRecentLogsUseCase
        )
        vm.events = events
        vm.completedTasks = completedTasks
        vm.pendingTasks = pendingTasks
        vm.memos = memos
        vm.completedEventCount = completedEventCount
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar

                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isGenerating {
                            generatingSection
                        } else if viewModel.summary != nil {
                            switch viewModel.selectedTab {
                            case .overview:         overviewTab
                            case .highlights:       highlightsTab
                            case .recommendations:  recommendationsTab
                            case .trends:           trendsTab
                            }
                        } else {
                            emptyStateSection
                        }

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI 업무 요약")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                if viewModel.summary == nil {
                    viewModel.generateSummary()
                }
            }
        }
    }
}

// MARK: - Tab Bar

private extension DailySummaryView {

    var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SummaryTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.caption)
                        .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(viewModel.selectedTab == tab ? tabColor(tab) : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedTab == tab ? tabBackgroundColor(tab) : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    func tabColor(_ tab: SummaryTab) -> Color {
        switch tab {
        case .overview:         return .indigo
        case .highlights:       return .orange
        case .recommendations:  return .blue
        case .trends:           return .green
        }
    }

    func tabBackgroundColor(_ tab: SummaryTab) -> Color {
        switch tab {
        case .overview:         return .indigo.opacity(0.1)
        case .highlights:       return .orange.opacity(0.1)
        case .recommendations:  return .blue.opacity(0.1)
        case .trends:           return .green.opacity(0.1)
        }
    }
}

// MARK: - Tab 1: 요약 (Overview)

private extension DailySummaryView {

    var overviewTab: some View {
        VStack(spacing: 20) {
            if let summary = viewModel.summary {
                scoreRing(summary)
                scoreBreakdownSection
                summaryTextCard(summary)
                metaChips(summary)
                regenerateButton
            }
        }
    }

    func scoreRing(_ summary: DailySummary) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: summary.productivityScore)
                    .stroke(
                        scoreGradient(for: summary.productivityScore),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: summary.productivityScore)

                VStack(spacing: 2) {
                    Text("\(viewModel.scorePercentage)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("점")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("오늘의 생산성")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("점수 구성")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(Array(viewModel.scoreBreakdown.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 10) {
                    Text(item.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.indigo)
                                .frame(
                                    width: geo.size.width * (item.value / item.maxValue),
                                    height: 8
                                )
                                .animation(.easeOut(duration: 0.8), value: item.value)
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(item.value))/\(Int(item.maxValue))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func summaryTextCard(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("요약", systemImage: "doc.text")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(summary.summaryText)
                .font(.subheadline)
                .lineSpacing(6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func metaChips(_ summary: DailySummary) -> some View {
        HStack(spacing: 10) {
            MetaChip(icon: "calendar", text: "일정 \(summary.totalEventMinutes)분")
            MetaChip(icon: "checkmark.circle", text: "완료 \(summary.completedTaskCount)건")
            let cat = WorkCategory(rawValue: summary.detectedCategory) ?? .general
            MetaChip(icon: "tag", text: "\(cat.emoji) \(cat.rawValue)")
        }
    }

    func scoreGradient(for score: Double) -> AngularGradient {
        let colors: [Color] = switch score {
        case 0.8...1.0: [.green, .mint, .green]
        case 0.6..<0.8: [.blue, .cyan, .blue]
        case 0.4..<0.6: [.orange, .yellow, .orange]
        default:        [.red, .orange, .red]
        }
        return AngularGradient(colors: colors, center: .center)
    }

    var regenerateButton: some View {
        Button { viewModel.generateSummary() } label: {
            Label("다시 생성하기", systemImage: "arrow.clockwise")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tab 2: 하이라이트 (Highlights)

private extension DailySummaryView {

    var highlightsTab: some View {
        VStack(spacing: 20) {
            if let summary = viewModel.summary, !summary.highlights.isEmpty {
                aiHighlightsCard(summary.highlights)
            }
            if !viewModel.categorizedHighlights.isEmpty {
                categorizedSection
            }
            if !viewModel.hourlyActivities.isEmpty {
                hourlyChart
            }
        }
    }

    func aiHighlightsCard(_ highlights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("핵심 하이라이트", systemImage: "star.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)

            ForEach(Array(highlights.enumerated()), id: \.offset) { index, highlight in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2).fontWeight(.bold)
                        .frame(width: 22, height: 22)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Circle())
                    Text(highlight)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.05)))
    }

    var categorizedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("카테고리별 활동", systemImage: "rectangle.3.group")
                .font(.subheadline).fontWeight(.semibold)

            ForEach(viewModel.categorizedHighlights) { group in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(group.category.emoji) \(group.category.rawValue)")
                            .font(.caption).fontWeight(.semibold)
                        Spacer()
                        if group.totalMinutes > 0 {
                            Text("\(group.totalMinutes)분")
                                .font(.caption2).foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(.systemGray5)).clipShape(Capsule())
                        }
                        Text("\(group.items.count)건")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(group.items, id: \.self) { item in
                        Text(item).font(.caption).foregroundStyle(.secondary).padding(.leading, 8)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("시간대별 활동", systemImage: "chart.bar.fill")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("가장 활발: \(viewModel.peakHourLabel)")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("일정").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("완료한 일").font(.caption2).foregroundStyle(.secondary)
                }
            }

            let maxCount = max(viewModel.hourlyActivities.map { $0.totalCount }.max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(viewModel.hourlyActivities) { activity in
                    VStack(spacing: 2) {
                        VStack(spacing: 0) {
                            Rectangle().fill(Color.green.opacity(0.7))
                                .frame(height: CGFloat(activity.taskCount) / CGFloat(maxCount) * 80)
                            Rectangle().fill(Color.blue.opacity(0.7))
                                .frame(height: CGFloat(activity.eventCount) / CGFloat(maxCount) * 80)
                        }
                        .frame(height: 80, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                        if activity.hour % 3 == 0 {
                            Text("\(activity.hour)").font(.system(size: 9)).foregroundStyle(.tertiary)
                        } else {
                            Text("").font(.system(size: 9))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tab 3: 추천 할 일 (Recommendations)

private extension DailySummaryView {

    var recommendationsTab: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("카드를 탭하면 상세 내용, + 버튼으로 미리알림 추가")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            HStack(spacing: 16) {
                VStack {
                    Text("\(viewModel.recommendedActions.filter { $0.priority == .critical }.count)")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.red)
                    Text("긴급").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(viewModel.recommendedActions.filter { $0.priority == .high }.count)")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.orange)
                    Text("중요").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(viewModel.recommendedActions.count)")
                        .font(.title2).fontWeight(.bold)
                    Text("전체").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ForEach(viewModel.recommendedActions) { action in
                recommendationRow(action)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedAction = action }
            }
            .sheet(item: $selectedAction) { action in
                recommendationDetailSheet(action)
            }

            if viewModel.recommendedActions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.green)
                    Text("모든 할 일을 완료했습니다!").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            }
        }
    }

    func recommendationRow(_ action: RecommendedAction) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor(action.priority))
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(action.title)
                        .font(.subheadline).fontWeight(.medium).lineLimit(1)
                    if action.isFromAI {
                        Text("AI")
                            .font(.system(size: 9)).fontWeight(.bold)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple).clipShape(Capsule())
                    }
                }
                Text(action.reason)
                    .font(.caption).foregroundStyle(priorityColor(action.priority))
            }

            Spacer()

            Button { viewModel.addToReminder(action) } label: {
                if viewModel.addedToReminder.contains(action.id) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Image(systemName: "plus.circle").foregroundStyle(.blue)
                }
            }
            .disabled(viewModel.addedToReminder.contains(action.id))
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func priorityColor(_ priority: RecommendedAction.ActionPriority) -> Color {
        switch priority {
        case .critical: return .red
        case .high:     return .orange
        case .normal:   return .blue
        case .low:      return .gray
        }
    }

    func recommendationDetailSheet(_ action: RecommendedAction) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // 우선순위 배지 + 제목
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(priorityLabel(action.priority))
                                .font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(priorityColor(action.priority).opacity(0.12))
                                .foregroundStyle(priorityColor(action.priority))
                                .clipShape(Capsule())

                            if action.isFromAI {
                                Text("AI 추천")
                                    .font(.caption).fontWeight(.semibold)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.12))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(action.title)
                            .font(.title3).fontWeight(.semibold)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(priorityColor(action.priority).opacity(0.05), in: RoundedRectangle(cornerRadius: 14))

                    // 추천 이유
                    VStack(alignment: .leading, spacing: 8) {
                        Label("추천 이유", systemImage: "info.circle")
                            .font(.subheadline).fontWeight(.semibold)
                        Text(action.reason)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    // 원본 태스크 정보 (있을 경우)
                    if let task = action.originalTask {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("태스크 정보", systemImage: "checklist")
                                .font(.subheadline).fontWeight(.semibold)

                            if !task.listName.isEmpty {
                                HStack {
                                    Text("목록").font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
                                    Text(task.listName).font(.subheadline)
                                }
                            }
                            if let due = task.dueDate {
                                HStack {
                                    Text("마감일").font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
                                    Text(due.formattedKorean)
                                        .font(.subheadline)
                                        .foregroundStyle(due < Date() ? .red : .primary)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // 미리알림 추가 버튼
                    Button {
                        viewModel.addToReminder(action)
                    } label: {
                        HStack {
                            if viewModel.addedToReminder.contains(action.id) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("미리알림에 추가됨")
                            } else {
                                Image(systemName: "bell.badge")
                                Text("미리알림에 추가")
                            }
                        }
                        .font(.subheadline).fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            viewModel.addedToReminder.contains(action.id)
                                ? Color.green.opacity(0.12)
                                : Color.blue.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(viewModel.addedToReminder.contains(action.id) ? .green : .blue)
                    }
                    .disabled(viewModel.addedToReminder.contains(action.id))
                }
                .padding()
            }
            .navigationTitle("추천 할 일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { selectedAction = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func priorityLabel(_ priority: RecommendedAction.ActionPriority) -> String {
        switch priority {
        case .critical: return "🔴 긴급"
        case .high:     return "🟠 중요"
        case .normal:   return "🔵 보통"
        case .low:      return "⚪ 낮음"
        }
    }
}

// MARK: - Tab 4: 트렌드 (Trends)

private extension DailySummaryView {

    var trendsTab: some View {
        VStack(spacing: 20) {
            weeklyAverageCard
            weeklyScoreChart
            weeklyActivityChart
            categoryDistributionChart
        }
    }

    var weeklyAverageCard: some View {
        HStack(spacing: 20) {
            VStack {
                Text("\(Int(viewModel.weeklyAverageScore * 100))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Text("주간 평균").font(.caption2).foregroundStyle(.secondary)
            }
            Divider().frame(height: 40)
            VStack {
                Text("\(viewModel.weeklyTrend.reduce(0) { $0 + $1.eventCount })")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("총 일정").font(.caption2).foregroundStyle(.secondary)
            }
            Divider().frame(height: 40)
            VStack {
                Text("\(viewModel.weeklyTrend.reduce(0) { $0 + $1.taskCount })")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("총 완료").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var weeklyScoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("주간 생산성 추이", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline).fontWeight(.semibold)

            let maxScore = max(viewModel.weeklyTrend.map { $0.score }.max() ?? 1, 0.01)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklyTrend) { point in
                    VStack(spacing: 4) {
                        if point.score > 0 {
                            Text("\(Int(point.score * 100))").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(point.score > 0
                                  ? Color.green.opacity(0.3 + point.score * 0.7)
                                  : Color(.systemGray5))
                            .frame(height: max(point.score / maxScore * 100, 4))
                            .animation(.easeOut(duration: 0.6), value: point.score)
                        Text(point.weekdayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(Calendar.current.isDateInToday(point.date) ? .primary : .secondary)
                            .fontWeight(Calendar.current.isDateInToday(point.date) ? .bold : .regular)
                        Text(point.dateLabel).font(.system(size: 8)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var weeklyActivityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("주간 활동량", systemImage: "chart.bar.fill")
                .font(.subheadline).fontWeight(.semibold)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("일정").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("완료").font(.caption2).foregroundStyle(.secondary)
                }
            }

            let maxActivity = max(
                viewModel.weeklyTrend.map { $0.eventCount + $0.taskCount }.max() ?? 1, 1
            )

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklyTrend) { point in
                    VStack(spacing: 4) {
                        VStack(spacing: 0) {
                            Rectangle().fill(Color.green.opacity(0.7))
                                .frame(height: CGFloat(point.taskCount) / CGFloat(maxActivity) * 80)
                            Rectangle().fill(Color.blue.opacity(0.7))
                                .frame(height: CGFloat(point.eventCount) / CGFloat(maxActivity) * 80)
                        }
                        .frame(height: 80, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text(point.weekdayLabel).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var categoryDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("주간 카테고리 분포", systemImage: "chart.pie.fill")
                .font(.subheadline).fontWeight(.semibold)

            if !viewModel.categoryDistribution.isEmpty {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(viewModel.categoryDistribution) { dist in
                            Rectangle()
                                .fill(categoryColor(dist.category))
                                .frame(width: geo.size.width * dist.percentage)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 16)

                ForEach(viewModel.categoryDistribution) { dist in
                    HStack(spacing: 8) {
                        Circle().fill(categoryColor(dist.category)).frame(width: 10, height: 10)
                        Text("\(dist.category.emoji) \(dist.category.rawValue)").font(.caption)
                        Spacer()
                        Text("\(dist.count)일").font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(dist.percentage * 100))%")
                            .font(.caption).fontWeight(.medium).frame(width: 36, alignment: .trailing)
                    }
                }
            } else {
                Text("주간 데이터가 부족합니다").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func categoryColor(_ category: WorkCategory) -> Color {
        switch category {
        case .development:   return .blue
        case .meeting:       return .purple
        case .planning:      return .orange
        case .documentation: return .green
        case .review:        return .teal
        case .exercise:      return .pink
        case .meal:          return .yellow
        case .medical:       return .red
        case .study:         return .indigo
        case .travel:        return .cyan
        case .shopping:      return Color(hex: "#FF9500") ?? .orange
        case .family:        return Color(hex: "#34C759") ?? .green
        case .hobby:         return Color(hex: "#AF52DE") ?? .purple
        case .general:       return .gray
        }
    }
}

// MARK: - Generating / Empty / Error

private extension DailySummaryView {

    var generatingSection: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5)
            Text(viewModel.generationProgress)
                .font(.subheadline).foregroundStyle(.secondary)
            Text("AI가 오늘 하루를 분석하고 있습니다...")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.top, 80)
    }

    var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text("AI 요약을 생성하려면\n일정이나 메모 데이터가 필요합니다")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button { viewModel.generateSummary() } label: {
                Label("요약 생성하기", systemImage: "sparkles").fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasEnoughData)
        }
        .padding(.top, 60)
    }

    func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption)
            Spacer()
            Button("재시도") { viewModel.generateSummary() }
                .font(.caption).fontWeight(.medium)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
