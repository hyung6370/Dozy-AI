//
//  MacInsightDashboardView.swift
//  Dozy AI (macOS)
//
//  M4.9 — 인사이트 대시보드. 기간(7/30/90일) 선택 + 요약 3종 카드 +
//  완료율 트렌드 / 요일별 평균 / 시간대 분포 / 반복 비율 / 카테고리 / 생산성 점수.
//  iOS 의 카테고리 분석 상세 / AI 인사이트 텍스트 카드 / Calendar source 배너 는 유보.
//

import SwiftUI
import Charts

struct MacInsightDashboardView: View {
    @StateObject private var viewModel: MacInsightViewModel

    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: MacInsightViewModel(container: container))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView().padding(.top, 80)
                } else if !viewModel.hasDozyData && !viewModel.hasWorkLogData {
                    emptyState
                } else {
                    headlineCard
                    summaryRow
                    completionTrendCard
                    weekdayCard
                    hourlyCard
                    recurrenceCard
                    if viewModel.hasWorkLogData {
                        productivityCard
                        categoryCard
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("인사이트")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("기간", selection: $viewModel.selectedPeriod) {
                    ForEach(MacInsightPeriod.allCases, id: \.self) { p in
                        Text(p.title).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .onAppear { viewModel.loadData() }
        .onChange(of: viewModel.selectedPeriod) { _, _ in viewModel.loadData() }
        .refreshable { viewModel.loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestRefresh)) { _ in
            viewModel.loadData()
        }
    }

    // MARK: - Empty

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

    // MARK: - Headline (가장 의미 있는 한 줄을 자동 추출)

    private var headlineCard: some View {
        let (title, message, icon, color) = headlineMessage()
        return HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(message)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [color.opacity(0.10), color.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
    }

    /// (라벨, 본문, 아이콘, 색상) — VM 의 시그널 중 가장 강한 것 우선.
    private func headlineMessage() -> (String, String, String, Color) {
        let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]

        // 1. 연속 달성 — streak 가 3일 이상이면 우선
        if viewModel.currentStreak >= 3 {
            return (
                "연속 달성 중",
                "\(viewModel.currentStreak)일 연속 일정을 완료하고 있어요 🔥",
                "flame.fill",
                .orange
            )
        }

        // 2. 평균 완료율 변화
        let change = viewModel.completionRateChange
        let pct = Int(viewModel.averageCompletionRate * 100)
        if change > 0.05 {
            return (
                "이번 기간 한눈에",
                "완료율이 \(Int(change * 100))% 개선됐어요. 평균 \(pct)% 달성!",
                "arrow.up.right.circle.fill",
                .green
            )
        } else if change < -0.05 {
            return (
                "이번 기간 한눈에",
                "완료율이 \(Int(abs(change) * 100))% 떨어졌어요. 평균 \(pct)%",
                "arrow.down.right.circle.fill",
                .red
            )
        }

        // 3. 가장 바쁜 요일
        if let busiest = viewModel.weekdayAvgCounts.max(by: { $0.avg < $1.avg }),
           busiest.avg > 0 {
            let label = weekdayLabels[safe: busiest.weekday] ?? ""
            return (
                "패턴 분석",
                "가장 바쁜 요일은 \(label)요일 (평균 \(String(format: "%.1f", busiest.avg))개)",
                "calendar.badge.clock",
                .blue
            )
        }

        // 4. fallback — 기본 인사
        return (
            "이번 기간 한눈에",
            "평균 완료율 \(pct)% — 꾸준히 잘 하고 있어요",
            "chart.line.uptrend.xyaxis",
            .indigo
        )
    }

    // MARK: - Summary

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.selectedPeriod.label)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)
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
    }

    private func summaryCard(value: String, label: String, change: Double?, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                Spacer()
                if let change {
                    HStack(spacing: 2) {
                        Image(systemName: trendIcon(for: change))
                        Text(trendLabel(for: change))
                    }
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(trendColor(for: change))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(trendColor(for: change).opacity(0.12), in: Capsule())
                }
            }
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [color.opacity(0.08), color.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
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

    // MARK: - Completion Trend

    private var completionTrendCard: some View {
        let isQuarter = viewModel.selectedPeriod == .quarter
        let useWeekly = isQuarter && !viewModel.weeklyCompletionRates.isEmpty
        let data = useWeekly ? viewModel.weeklyCompletionRates : viewModel.dailyCompletionRates
        let title = useWeekly ? "주간 평균 완료율" : "일별 완료율"

        return InsightCard(title: title, systemImage: "chart.line.uptrend.xyaxis", accent: .green) {
            if data.isEmpty {
                cardEmpty(message: "완료 데이터가 없습니다")
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        LineMark(
                            x: .value("날짜", item.date),
                            y: .value("완료율", item.rate)
                        )
                        .foregroundStyle(.green)
                        AreaMark(
                            x: .value("날짜", item.date),
                            y: .value("완료율", item.rate)
                        )
                        .foregroundStyle(.green.opacity(0.12))
                    }
                }
                .chartYScale(domain: 0...1)
                .frame(height: 180)
            }
        }
    }

    // MARK: - Weekday

    private var weekdayCard: some View {
        let labels = ["일", "월", "화", "수", "목", "금", "토"]
        return InsightCard(title: "요일별 평균 일정 수", systemImage: "calendar", accent: .blue) {
            if viewModel.weekdayAvgCounts.isEmpty {
                cardEmpty(message: "일정 데이터가 없습니다")
            } else {
                Chart {
                    ForEach(viewModel.weekdayAvgCounts, id: \.weekday) { item in
                        BarMark(
                            x: .value("요일", labels[item.weekday]),
                            y: .value("평균", item.avg)
                        )
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Hourly

    private var hourlyCard: some View {
        InsightCard(title: "시간대 분포", systemImage: "clock", accent: .orange) {
            if viewModel.hourlyDistribution.isEmpty {
                cardEmpty(message: "일정 데이터가 없습니다")
            } else {
                Chart {
                    ForEach(viewModel.hourlyDistribution, id: \.hour) { item in
                        BarMark(
                            x: .value("시", item.hour),
                            y: .value("건수", item.count)
                        )
                        .foregroundStyle(viewModel.peakHours.contains(item.hour) ? Color.orange : Color.blue)
                        .cornerRadius(3)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text("\(hour)시")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Recurrence

    private var recurrenceCard: some View {
        let total = viewModel.recurringCount + viewModel.oneTimeCount
        return InsightCard(title: "반복 vs 일회성", systemImage: "repeat", accent: .purple) {
            if total == 0 {
                cardEmpty(message: "일정 데이터가 없습니다")
            } else {
                HStack(spacing: 20) {
                    stat(
                        value: "\(viewModel.recurringCount)",
                        label: "반복 일정",
                        ratio: Double(viewModel.recurringCount) / Double(total),
                        color: .purple
                    )
                    stat(
                        value: "\(viewModel.oneTimeCount)",
                        label: "일회성 일정",
                        ratio: Double(viewModel.oneTimeCount) / Double(total),
                        color: .teal
                    )
                }
            }
        }
    }

    private func stat(value: String, label: String, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: ratio)
                .tint(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Productivity

    private var productivityCard: some View {
        InsightCard(title: "일별 생산성 점수", systemImage: "sparkles", accent: .indigo) {
            if viewModel.productivityScores.isEmpty {
                cardEmpty(message: "생산성 기록이 없습니다")
            } else {
                Chart {
                    ForEach(viewModel.productivityScores, id: \.date) { item in
                        LineMark(
                            x: .value("날짜", item.date),
                            y: .value("점수", item.score)
                        )
                        .foregroundStyle(.indigo)
                        PointMark(
                            x: .value("날짜", item.date),
                            y: .value("점수", item.score)
                        )
                        .foregroundStyle(.indigo)
                    }
                }
                .chartYScale(domain: 0...1)
                .frame(height: 180)
            }
        }
    }

    // MARK: - Category

    private var categoryCard: some View {
        InsightCard(title: "카테고리 분포", systemImage: "chart.pie.fill", accent: .pink) {
            if viewModel.categoryDistribution.isEmpty {
                cardEmpty(message: "카테고리 기록이 없습니다")
            } else {
                let maxCount = viewModel.categoryDistribution.first?.count ?? 1
                VStack(spacing: 10) {
                    ForEach(viewModel.categoryDistribution.prefix(6), id: \.category) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.category)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(item.count), total: Double(max(maxCount, 1)))
                                .tint(.pink)
                                .scaleEffect(y: 0.7)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func cardEmpty(message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 8)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - InsightCard Container

private struct InsightCard<Content: View>: View {
    let title: String
    let systemImage: String
    var accent: Color = .secondary
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
