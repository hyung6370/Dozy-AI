//
//  InsightDashboardView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/2/26.
//

import SwiftUI
import Charts

struct InsightDashboardView: View {
    
    @StateObject private var viewModel: InsightDashboardViewModel
    
    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: InsightDashboardViewModel(
            fetchEventsUseCase: container.fetchDozyEventsForPeriodUseCase,
            fetchCompletionsUseCase: container.fetchEventCompletionsForPeriodUseCase,
            fetchLogsUseCase: container.fetchRecentLogsUseCase,
            patternService: container.patternAnalysisService
        ))
    }
    
    private let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    } else if !viewModel.hasDozyData && !viewModel.hasWorkLogData {
                        emptyState
                    } else {
                        if !viewModel.insights.isEmpty {
                            insightCard
                        }
                        summaryRow
                        chartSectionPager
                    }
                }
                .padding()
            }
            .navigationTitle("인사이트")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("기간", selection: $viewModel.selectedPeriod) {
                        ForEach(InsightPeriod.allCases, id: \.self) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.loadData()
            }
            .onAppear { viewModel.loadData() }
            .refreshable { viewModel.loadData() }
        }
    }
    
    // MARK: - Insight Card
    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI 인사이트", systemImage: "sparkles")
                .font(.headline)
            ForEach(viewModel.insights) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.icon)
                        .foregroundStyle(insight.color)
                        .frame(width: 20)
                    Text(insight.text)
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("아직 분석할 데이터가 없어요")
                .font(.headline)
            Text("Dozy에 일정을 추가하면\n패턴 분석을 시작할 수 있어요")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
    }
    
    // MARK: - 요약 3종 카드
    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryCard(
                value: "\(Int(viewModel.averageCompletionRate * 100))%",
                label: "평균 완료율",
                change: viewModel.completionRateChange,
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            summaryCard(
                value: "\(viewModel.currentStreak)일",
                label: "연속 달성",
                change: nil,
                icon: "flame.fill",
                color: .orange
            )
            
            if let score = viewModel.averageProductivityScore {
                summaryCard(
                    value: "\(Int(score * 100))점",
                    label: "생산성 점수",
                    change: nil,
                    icon: "star.fill",
                    color: .yellow
                )
            }
        }
    }
    
    private func summaryCard(value: String, label: String, change: Double?, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let change {
                HStack(spacing: 2) {
                    Image(systemName: trendIcon(for: change))
                    Text(trendLabel(for: change))
                }
                .font(.caption2)
                .foregroundStyle(trendColor(for: change))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    private func trendIcon(for change: Double) -> String {
        if change > 0.02 { return "arrow.up.right" }
        if change < -0.02 { return "arrow.down.right" }
        return "arrow.right"
    }
    
    private func trendLabel(for change: Double) -> String {
        if abs(change) < 0.02 { return "이전과 동일" }
        return "\(Int(abs(change) * 100))% \(change >= 0 ? "개선" : "감소")"
    }
    
    private func trendColor(for change: Double) -> Color {
        if change > 0.02 { return .green }
        if change < -0.02 { return .red }
        return .secondary
    }

    // MARK: - 섹션별 스와이프 Pager
    private var chartSectionPager: some View {
        TabView {
            // 섹션 1 — 완료 분석
            VStack(spacing: 16) {
                completionTrendCard
                weekdayCard
            }
            .padding(.horizontal, 4)
            .tag(0)

            // 섹션 2 — 시간 패턴
            VStack(spacing: 16) {
                hourlyCard
                recurrenceCard
            }
            .padding(.horizontal, 4)
            .tag(1)

            // 섹션 3 — 업무 / 생산성
            VStack(spacing: 16) {
                productivityCard
                categoryCard
            }
            .padding(.horizontal, 4)
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 520)
    }

    // MARK: - 카드 Empty State 공통
    private func cardEmptyState(icon: String = "tray", message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 8)
    }

    // MARK: - 일별 완료율 트렌드
    private var completionTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("일별 완료율", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            if viewModel.dailyCompletionRates.isEmpty {
                cardEmptyState(icon: "checkmark.circle", message: "일정을 완료하면\n완료율 추이를 볼 수 있어요")
            } else {
                Chart(viewModel.dailyCompletionRates, id: \.date) { item in
                    LineMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("완료율", item.rate * 100)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("완료율", item.rate * 100)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) {
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - 시간대별 집중도
    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("시간대별 집중도", systemImage: "clock")
                .font(.headline)
            if viewModel.hourlyDistribution.isEmpty {
                cardEmptyState(icon: "clock", message: "일정이 쌓이면\n시간대별 패턴을 분석할 수 있어요")
            } else {
                if !viewModel.peakHours.isEmpty {
                    Text("피크 시간대: \(viewModel.peakHours.map { "\($0)시" }.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Chart(viewModel.hourlyDistribution, id: \.hour) { item in
                    BarMark(
                        x: .value("시간", "\(item.hour)시"),
                        y: .value("이벤트 수", item.count)
                    )
                    .foregroundStyle(
                        viewModel.peakHours.contains(item.hour)
                        ? Color.orange.gradient
                        : Color.accentColor.opacity(0.5).gradient
                    )
                    .cornerRadius(3)
                }
                .frame(height: 130)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - 요일별 평균
    private var weekdayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("요일별 평균 일정 수", systemImage: "calendar")
                .font(.headline)
            if viewModel.weekdayAvgCounts.allSatisfy({ $0.avg == 0 }) {
                cardEmptyState(icon: "calendar.badge.plus", message: "일정을 더 추가하면\n요일 패턴을 확인할 수 있어요")
            } else {
                Chart(viewModel.weekdayAvgCounts, id: \.weekday) { item in
                    BarMark(
                        x: .value("요일", weekdayLabels[item.weekday]),
                        y: .value("평균", item.avg)
                    )
                    .foregroundStyle(Color.purple.opacity(0.7).gradient)
                    .cornerRadius(4)
                }
                .frame(height: 130)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - 반복 vs 단발성
    private var recurrenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("일정 유형 분포", systemImage: "arrow.trianglehead.clockwise")
                .font(.headline)
            HStack(spacing: 2) {
                let total = viewModel.recurringCount + viewModel.oneTimeCount
                if total > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue)
                                .frame(width: geo.size.width * CGFloat(viewModel.recurringCount) / CGFloat(total))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.teal)
                        }
                    }
                    .frame(height: 12)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.recurringCount)개")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.blue)
                    Text("반복 일정")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.oneTimeCount)개")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.teal)
                    Text("단발성 일정")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - 생산성 점수 추이
    private var productivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("생산성 점수 추이", systemImage: "star.fill")
                .font(.headline)
            if viewModel.productivityScores.isEmpty {
                cardEmptyState(icon: "star", message: "AI 일일 요약을 생성하면\n생산성 점수를 추적할 수 있어요")
            } else {
                Chart(viewModel.productivityScores, id: \.date) { item in
                    LineMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("점수", item.score * 100)
                    )
                    .foregroundStyle(Color.yellow)
                    .symbol(.circle)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 130)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 카테고리 분포
    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("업무 카테고리", systemImage: "chart.pie")
                .font(.headline)
            if viewModel.categoryDistribution.isEmpty {
                cardEmptyState(icon: "chart.pie", message: "AI 요약이 쌓이면\n카테고리 분포를 볼 수 있어요")
            } else {
                Chart(viewModel.categoryDistribution, id: \.category) { item in
                    SectorMark(
                        angle: .value("횟수", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("카테고리", item.category))
                    .cornerRadius(4)
                }
                .frame(height: 160)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
