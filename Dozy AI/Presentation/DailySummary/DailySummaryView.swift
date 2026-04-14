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
import SwiftData

struct DailySummaryView: View {

    @StateObject private var viewModel: DailySummaryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAction: RecommendedAction? = nil
    @Query(sort: \UserCategory.order) private var userCategories: [UserCategory]

    init(
        generateSummaryUseCase: GenerateDailySummaryUseCase,
        fetchRecentLogsUseCase: FetchRecentLogsUseCase,
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String],
        completedEventCount: Int = 0,
        existingSummary: DailySummary? = nil
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
        // 이미 생성된 요약이 있으면 주입 → onAppear에서 재생성 안 함
        if let existing = existingSummary {
            vm.summary = existing
            vm.buildHighlightsData()
            vm.buildRecommendationsData()
            vm.buildTrendsData()
        }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar

                if viewModel.isGenerating {
                    ScrollView {
                        VStack(spacing: 20) {
                            generatingSection
                        }
                        .padding()
                    }
                } else if viewModel.summary != nil {
                    TabView(selection: Binding(
                        get: { viewModel.selectedTab },
                        set: { newTab in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedTab = newTab
                            }
                        }
                    )) {
                        dailyTab.tag(SummaryTab.daily)
                        weeklyTab.tag(SummaryTab.weekly)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            emptyStateSection
                            if let error = viewModel.errorMessage { errorBanner(error) }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Dozy 일정 요약")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                viewModel.userCategories = userCategories
                viewModel.buildCategoryAnalysis()
                if viewModel.summary == nil {
                    viewModel.generateSummary()
                } else {
                    viewModel.buildHighlightsData()
                    viewModel.buildTrendsData()
                }
            }
            .onChange(of: userCategories) { _, new in
                viewModel.userCategories = new
                viewModel.buildCategoryAnalysis()
                viewModel.buildHighlightsData()
                viewModel.buildTrendsData()
            }
        }
    }
}

// MARK: - Tab Bar

private extension DailySummaryView {

    var tabBar: some View {
        Picker("", selection: Binding(
            get: { viewModel.selectedTab },
            set: { newTab in withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedTab = newTab } }
        )) {
            ForEach(SummaryTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    func tabColor(_ tab: SummaryTab) -> Color {
        switch tab {
        case .daily:  return .indigo
        case .weekly: return .green
        }
    }

    func tabBackgroundColor(_ tab: SummaryTab) -> Color {
        switch tab {
        case .daily:  return .indigo.opacity(0.1)
        case .weekly: return .green.opacity(0.1)
        }
    }
}

// MARK: - Daily / Weekly Tab

private extension DailySummaryView {

    var dailyTab: some View {
        ScrollView {
            VStack(spacing: 28) {
                tabSectionHeader(title: "오늘 요약", icon: "doc.text.fill", color: .indigo)
                overviewTab
                tabSectionDivider
                tabSectionHeader(title: "하이라이트", icon: "star.fill", color: .orange)
                highlightsTab
                tabSectionDivider
                tabSectionHeader(title: "카테고리 분석", icon: "chart.pie.fill", color: .purple)
                categoryTab
                if let error = viewModel.errorMessage { errorBanner(error) }
            }
            .padding()
        }
    }

    var weeklyTab: some View {
        ScrollView {
            VStack(spacing: 28) {
                tabSectionHeader(title: "주간 트렌드", icon: "chart.line.uptrend.xyaxis", color: .green)
                trendsTab
            }
            .padding()
        }
    }

    private func tabSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
        }
    }

    private var tabSectionDivider: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 1)
            .padding(.vertical, 4)
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
        let catName = summary.detectedCategory
        let catEmoji = userCategories.first(where: { $0.name == catName })?.emoji ?? "📌"

        // 전체 일정 수 (종일 포함, 리마인더 제외)
        let totalEventCount = viewModel.events.count

        // 완료 일정: 종료된 시간제 일정 또는 명시적으로 완료된 일정 (Dozy isCompleted)
        // 종일 일정은 당일 자동 완료 불가 → Dozy 명시 완료만 반영
        let timeElapsed = viewModel.events.filter { !$0.isAllDay && $0.endDate <= Date() }.count
        let elapsedCount = max(timeElapsed, viewModel.completedEventCount)

        // 남은 일정 = 전체 - 완료 (endDate 기반이 아닌 차감 방식)
        // endDate 기반이면 명시적 완료(isCompleted) 이벤트도 "남은" 것으로 잡히는 오류가 있음
        let remainingCount = max(0, totalEventCount - elapsedCount)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                metaCell(icon: "calendar",         label: "일정",    value: "\(totalEventCount)건")
                metaCell(icon: "checkmark.circle", label: "완료",    value: "\(elapsedCount)건")
            }
            HStack(spacing: 8) {
                metaCell(icon: "circle",           label: "남은 일정", value: "\(remainingCount)건")
                metaCell(icon: "tag",              label: "오늘의 주요 카테고리", value: "\(catEmoji) \(catName)")
            }
            Text("Dozy · Apple · Google 캘린더 일정 기준으로 표시됩니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    private func metaCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        Text("\(group.category.emoji) \(group.category.name)")
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
                Text("탭: 상세보기, +: 미리알림 추가, AI카드 왼쪽 스와이프: 삭제")
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

            List {
                ForEach(viewModel.recommendedActions) { action in
                    recommendationRow(action)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedAction = action }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if action.isFromAI {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.removeAction(action)
                                    }
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.recommendedActions.count) * 82)
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
                Text("\(viewModel.weeklyTrend.filter { $0.eventCount > 0 }.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("활동일").font(.caption2).foregroundStyle(.secondary)
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

            let maxActivity = max(
                viewModel.weeklyTrend.map { $0.eventCount }.max() ?? 1, 1
            )

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklyTrend) { point in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(point.eventCount > 0 ? Color.blue.opacity(0.7) : Color(.systemGray5))
                            .frame(height: max(CGFloat(point.eventCount) / CGFloat(maxActivity) * 80, 4))
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
                        Text("\(dist.category.emoji) \(dist.category.name)").font(.caption)
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

    func categoryColor(_ category: CategoryInfo) -> Color {
        Color(hex: category.colorHex) ?? .gray
    }
}

// MARK: - Tab 5: 카테고리 분석

private extension DailySummaryView {

    var categoryTab: some View {
        VStack(spacing: 20) {
            categoryOverviewCard
            if !viewModel.categoryTimeStats.isEmpty {
                categoryTimeDistributionCard
                categoryCountBarCard
                categoryPeakHourCard
            }
            categoryWeeklyDominanceCard
            categoryFocusScoreCard
        }
    }

    // MARK: 개요 카드
    var categoryOverviewCard: some View {
        let stats = viewModel.categoryTimeStats
        let topByTime  = stats.first
        let topByCount = stats.max(by: { $0.eventCount < $1.eventCount })
        let totalEvents = stats.reduce(0) { $0 + $1.eventCount }

        return VStack(spacing: 12) {
            HStack {
                Label("카테고리 분석", systemImage: "chart.pie.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.purple)
                Spacer()
                Text("총 \(stats.count)개 카테고리")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(totalEvents)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("오늘 일정").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                VStack(spacing: 4) {
                    if let top = topByTime {
                        Text("\(top.category.emoji) \(top.category.name)")
                            .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                        Text("가장 긴 시간").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("—").font(.subheadline)
                        Text("가장 긴 시간").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                VStack(spacing: 4) {
                    if let top = topByCount {
                        Text("\(top.category.emoji) \(top.category.name)")
                            .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                        Text("가장 많은 일정").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("—").font(.subheadline)
                        Text("가장 많은 일정").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: 시간 분배
    var categoryTimeDistributionCard: some View {
        let stats = viewModel.categoryTimeStats
        let hasTime = stats.contains { $0.totalMinutes > 0 }

        return VStack(alignment: .leading, spacing: 12) {
            Label("시간 분배", systemImage: "clock.fill")
                .font(.subheadline).fontWeight(.semibold)

            // 세그먼트 바
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stats) { stat in
                        let w = hasTime
                            ? geo.size.width * stat.percentage
                            : geo.size.width * stat.countPercentage
                        if w > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(catColor(stat.category))
                                .frame(width: max(w - 2, 2))
                        }
                    }
                }
            }
            .frame(height: 18)

            // 범례
            VStack(spacing: 8) {
                ForEach(stats) { stat in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(catColor(stat.category))
                            .frame(width: 10, height: 10)
                        Text("\(stat.category.emoji) \(stat.category.name)")
                            .font(.caption)
                        Spacer()
                        if hasTime && stat.totalMinutes > 0 {
                            Text(minuteLabel(stat.totalMinutes))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(hasTime
                             ? "\(Int(stat.percentage * 100))%"
                             : "\(Int(stat.countPercentage * 100))%")
                            .font(.caption).fontWeight(.medium)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            if !hasTime {
                Text("종일 일정만 있어 시간 기준 대신 건수 기준으로 표시됩니다")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 일정 건수 바 차트
    var categoryCountBarCard: some View {
        let stats = viewModel.categoryTimeStats
        let maxCount = max(stats.map { $0.eventCount }.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Label("일정 건수", systemImage: "calendar.badge.clock")
                .font(.subheadline).fontWeight(.semibold)

            ForEach(stats) { stat in
                HStack(spacing: 10) {
                    Text("\(stat.category.emoji) \(stat.category.name)")
                        .font(.caption)
                        .frame(width: 90, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray4))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(catColor(stat.category))
                                .frame(
                                    width: geo.size.width * CGFloat(stat.eventCount) / CGFloat(maxCount),
                                    height: 12
                                )
                                .animation(.easeOut(duration: 0.6), value: stat.eventCount)
                        }
                    }
                    .frame(height: 12)

                    Text("\(stat.eventCount)건")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 피크 시간대
    var categoryPeakHourCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("선호 시간대", systemImage: "sun.max.fill")
                .font(.subheadline).fontWeight(.semibold)

            ForEach(viewModel.categoryHourStats) { stat in
                HStack(spacing: 12) {
                    Text("\(stat.category.emoji) \(stat.category.name)")
                        .font(.caption)
                        .frame(width: 90, alignment: .leading)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text(stat.peakHourLabel)
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(catColor(stat.category).opacity(0.15))
                        .foregroundStyle(catColor(stat.category))
                        .clipShape(Capsule())
                    Spacer()
                }
            }

            if viewModel.categoryHourStats.isEmpty {
                Text("시간 데이터가 있는 일정이 없습니다")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 주간 카테고리 지배 패턴
    var categoryWeeklyDominanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("주간 카테고리 패턴", systemImage: "calendar.badge.checkmark")
                .font(.subheadline).fontWeight(.semibold)

            if !viewModel.weeklyTrend.isEmpty {
                HStack(spacing: 6) {
                    ForEach(viewModel.weeklyTrend) { point in
                        let catInfo = viewModel.categoryTimeStats
                            .first(where: { $0.category.name == point.category })?.category
                            ?? CategoryInfo(name: point.category, emoji: "📌", colorHex: "#8E8E93")
                        let isToday = Calendar.current.isDateInToday(point.date)

                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(point.score > 0
                                          ? (Color(hex: catInfo.colorHex) ?? .gray).opacity(0.25)
                                          : Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                if point.score > 0 {
                                    Text(catInfo.emoji).font(.subheadline)
                                } else {
                                    Text("—").font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .overlay(
                                isToday
                                    ? Circle().stroke(Color.purple, lineWidth: 2)
                                    : nil
                            )
                            Text(point.weekdayLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(isToday ? .purple : .secondary)
                                .fontWeight(isToday ? .bold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // 범례
                let usedCategories = Set(viewModel.weeklyTrend.map { $0.category })
                let legendItems = viewModel.categoryTimeStats.filter { usedCategories.contains($0.category.name) }
                if !legendItems.isEmpty {
                    Divider()
                    FlowLayout(spacing: 6) {
                        ForEach(legendItems) { stat in
                            HStack(spacing: 4) {
                                Text(stat.category.emoji).font(.caption2)
                                Text(stat.category.name).font(.caption2)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(catColor(stat.category).opacity(0.12))
                            .foregroundStyle(catColor(stat.category))
                            .clipShape(Capsule())
                        }
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

    // MARK: 집중도 점수
    var categoryFocusScoreCard: some View {
        let stats = viewModel.categoryTimeStats
        let focusScore: Double
        let focusLabel: String
        let focusColor: Color

        if stats.isEmpty {
            focusScore = 0
            focusLabel = "데이터 없음"
            focusColor = .gray
        } else if stats.count == 1 {
            focusScore = 1.0
            focusLabel = "완전 집중"
            focusColor = .green
        } else {
            // HHI (허핀달-허쉬만 지수): 비중 제곱합
            let hhi = stats.reduce(0.0) { $0 + pow($1.countPercentage, 2) }
            focusScore = hhi
            switch hhi {
            case 0.6...: focusLabel = "집중형"; focusColor = .green
            case 0.35..<0.6: focusLabel = "균형형"; focusColor = .blue
            default: focusLabel = "분산형"; focusColor = .orange
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            Label("집중도 분석", systemImage: "scope")
                .font(.subheadline).fontWeight(.semibold)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: focusScore)
                        .stroke(focusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: focusScore)
                    Text("\(Int(focusScore * 100))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(focusColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(focusLabel)
                        .font(.headline).fontWeight(.semibold)
                        .foregroundStyle(focusColor)
                    Text(focusDescription(stats.count))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Helpers
    func catColor(_ category: CategoryInfo) -> Color {
        Color(hex: category.colorHex) ?? .gray
    }

    func minuteLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)시간 \(m)분" : "\(h)시간"
        }
        return "\(minutes)분"
    }

    func focusDescription(_ categoryCount: Int) -> String {
        switch categoryCount {
        case 1: return "오늘 하나의 카테고리에 집중했어요"
        case 2: return "두 가지 영역에 균형 있게 시간을 썼어요"
        default: return "\(categoryCount)개 카테고리에 걸쳐 다양하게 활동했어요"
        }
    }
}

// MARK: - FlowLayout (태그 줄바꿈용)
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.endIndex - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.endIndex - 1].append(subview)
            x += size.width + spacing
        }
        return rows
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
