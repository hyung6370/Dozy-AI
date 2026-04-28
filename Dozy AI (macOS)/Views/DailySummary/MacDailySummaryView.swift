//
//  MacDailySummaryView.swift
//  Dozy AI (macOS)
//
//  iOS DailySummaryView 의 macOS 포팅 — 같은 ViewModel(DailySummaryViewModel) 공유.
//  iOS 가 page-style TabView 로 Daily / Weekly 를 swipe 하는 반면 macOS 는 swipe 가
//  비대중적이라 상단 segmented Picker + 단일 ScrollView 패턴 사용.
//
//  Phase M5.1.b — Daily 탭 (Overview · Highlights · Category 분석) 완성.
//                  Weekly 탭은 5.1.c, MacTodayView trigger 는 5.1.d.
//

import SwiftUI
import SwiftData

struct MacDailySummaryView: View {

    @StateObject private var viewModel: DailySummaryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAction: RecommendedAction? = nil
    @Query(sort: \UserCategory.order) private var userCategories: [UserCategory]

    var onSummaryGenerated: ((DailySummary) -> Void)?

    init(
        generateSummaryUseCase: GenerateDailySummaryUseCase,
        fetchRecentLogsUseCase: FetchRecentLogsUseCase,
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String],
        completedEventCount: Int = 0,
        existingSummary: DailySummary? = nil,
        onSummaryGenerated: ((DailySummary) -> Void)? = nil
    ) {
        self.onSummaryGenerated = onSummaryGenerated
        let vm = DailySummaryViewModel(
            generateSummaryUseCase: generateSummaryUseCase,
            fetchRecentLogsUseCase: fetchRecentLogsUseCase
        )
        vm.events = events
        vm.completedTasks = completedTasks
        vm.pendingTasks = pendingTasks
        vm.memos = memos
        vm.completedEventCount = completedEventCount
        if let existing = existingSummary {
            vm.summary = existing
            vm.buildHighlightsData()
            vm.buildRecommendationsData()
            vm.buildTrendsData()
        }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()

            if viewModel.isGenerating {
                ScrollView {
                    generatingSection
                        .padding(20)
                }
            } else if viewModel.summary != nil {
                ScrollView {
                    Group {
                        switch viewModel.selectedTab {
                        case .daily:  dailyTab
                        case .weekly: weeklyTab
                        }
                    }
                    .padding(20)
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        emptyStateSection
                        if let error = viewModel.errorMessage { errorBanner(error) }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Dozy 일정 요약")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
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
        .onChange(of: viewModel.summary) { _, newSummary in
            if let newSummary {
                onSummaryGenerated?(newSummary)
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        Picker("", selection: $viewModel.selectedTab) {
            ForEach(SummaryTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Daily 탭

    private var dailyTab: some View {
        VStack(spacing: 28) {
            tabSectionHeader(title: "오늘 요약", icon: "doc.text.fill", color: .indigo)
            overviewSection
            tabSectionDivider
            tabSectionHeader(title: "하이라이트", icon: "star.fill", color: .orange)
            highlightsSection
            tabSectionDivider
            tabSectionHeader(title: "카테고리 분석", icon: "chart.pie.fill", color: .purple)
            categorySection
            if let error = viewModel.errorMessage { errorBanner(error) }
        }
    }

    // MARK: - Weekly 탭

    private var weeklyTab: some View {
        VStack(spacing: 28) {
            tabSectionHeader(title: "주간 트렌드", icon: "chart.line.uptrend.xyaxis", color: .green)
            weeklyAverageCard
            weeklyScoreChart
            weeklyActivityChart
            categoryDistributionChart
        }
    }

    // MARK: - Empty / Generating

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.indigo)
            Text("요약을 생성할 수 없습니다")
                .font(.headline)
            Text("오늘 등록된 일정이나 메모가 부족합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }

    private var generatingSection: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(viewModel.generationProgress.isEmpty ? "AI 요약 생성 중..." : viewModel.generationProgress)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
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
            .fill(Color.gray.opacity(0.12))
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

// MARK: - Overview 섹션

private extension MacDailySummaryView {

    var overviewSection: some View {
        VStack(spacing: 20) {
            if let summary = viewModel.summary {
                scoreRing(summary)
                scoreBreakdownCard
                summaryTextCard(summary)
                metaGrid(summary)
                regenerateButton
            }
        }
    }

    func scoreRing(_ summary: DailySummary) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.18), lineWidth: 12)
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
        .frame(maxWidth: .infinity)
    }

    var scoreBreakdownCard: some View {
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
                                .fill(Color.gray.opacity(0.18))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.indigo)
                                .frame(
                                    width: geo.size.width * (item.value / max(item.maxValue, 0.01)),
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
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
        .background(cardBackground)
    }

    func metaGrid(_ summary: DailySummary) -> some View {
        let catName = summary.detectedCategory
        let catEmoji = userCategories.first(where: { $0.name == catName })?.emoji ?? "📌"
        let totalEventCount = viewModel.events.count
        let timeElapsed = viewModel.events.filter { !$0.isAllDay && $0.endDate <= Date() }.count
        let elapsedCount = max(timeElapsed, viewModel.completedEventCount)
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

    func metaCell(icon: String, label: String, value: String) -> some View {
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
        .background(cardBackground)
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
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Highlights 섹션

private extension MacDailySummaryView {

    var highlightsSection: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
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
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text("\(group.items.count)건")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(group.items, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
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
                            Text("\(activity.hour)")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("").font(.system(size: 9))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

// MARK: - Category 분석 섹션

private extension MacDailySummaryView {

    var categorySection: some View {
        VStack(spacing: 20) {
            categoryOverviewCard
            if !viewModel.categoryTimeStats.isEmpty {
                categoryTimeDistributionCard
                categoryCountBarCard
                categoryPeakHourCard
            }
            categoryFocusScoreCard
        }
    }

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    var categoryTimeDistributionCard: some View {
        let stats = viewModel.categoryTimeStats
        let hasTime = stats.contains { $0.totalMinutes > 0 }

        return VStack(alignment: .leading, spacing: 12) {
            Label("시간 분배", systemImage: "clock.fill")
                .font(.subheadline).fontWeight(.semibold)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

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
                        .frame(width: 100, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
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
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var categoryPeakHourCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("선호 시간대", systemImage: "sun.max.fill")
                .font(.subheadline).fontWeight(.semibold)

            ForEach(viewModel.categoryHourStats) { stat in
                HStack(spacing: 12) {
                    Text("\(stat.category.emoji) \(stat.category.name)")
                        .font(.caption)
                        .frame(width: 100, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

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
            let hhi = stats.reduce(0.0) { $0 + pow($1.countPercentage, 2) }
            focusScore = hhi
            switch hhi {
            case 0.6...:    focusLabel = "집중형"; focusColor = .green
            case 0.35..<0.6: focusLabel = "균형형"; focusColor = .blue
            default:        focusLabel = "분산형"; focusColor = .orange
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            Label("집중도 분석", systemImage: "scope")
                .font(.subheadline).fontWeight(.semibold)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.18), lineWidth: 8)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

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

// MARK: - Weekly 트렌드 카드

private extension MacDailySummaryView {

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
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
                            Text("\(Int(point.score * 100))")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(point.score > 0
                                  ? Color.green.opacity(0.3 + point.score * 0.7)
                                  : Color.gray.opacity(0.18))
                            .frame(height: max(point.score / maxScore * 100, 4))
                            .animation(.easeOut(duration: 0.6), value: point.score)
                        Text(point.weekdayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(Calendar.current.isDateInToday(point.date) ? .primary : .secondary)
                            .fontWeight(Calendar.current.isDateInToday(point.date) ? .bold : .regular)
                        Text(point.dateLabel)
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var weeklyActivityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("주간 활동량", systemImage: "chart.bar.fill")
                .font(.subheadline).fontWeight(.semibold)

            let maxActivity = max(viewModel.weeklyTrend.map { $0.eventCount }.max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklyTrend) { point in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(point.eventCount > 0
                                  ? Color.blue.opacity(0.7)
                                  : Color.gray.opacity(0.18))
                            .frame(height: max(CGFloat(point.eventCount) / CGFloat(maxActivity) * 80, 4))
                        Text(point.weekdayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
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
                                .fill(catColor(dist.category))
                                .frame(width: geo.size.width * dist.percentage)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 16)

                ForEach(viewModel.categoryDistribution) { dist in
                    HStack(spacing: 8) {
                        Circle().fill(catColor(dist.category)).frame(width: 10, height: 10)
                        Text("\(dist.category.emoji) \(dist.category.name)").font(.caption)
                        Spacer()
                        Text("\(dist.count)일").font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(dist.percentage * 100))%")
                            .font(.caption).fontWeight(.medium)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            } else {
                Text("주간 데이터가 부족합니다")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

// MARK: - 공통 카드 배경

private extension MacDailySummaryView {
    var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}
