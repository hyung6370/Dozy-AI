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
            fetchRecentLogsUseCase: container.fetchRecentLogsUseCase,
            patternService: container.patternAnalysisService
        ))
    }
    
    private let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView().padding(.top, 60)
                    } else {
                        averageScoreCard
                        weeklyChart
                        weekdayChart
                        categoryChart
                        highlightsSection
                    }
                }
                .padding()
            }
            .navigationTitle("인사이트")
            .onAppear { viewModel.loadData() }
            .refreshable { viewModel.loadData() }
        }
    }
    
    // MARK: - 평균 생산성 카드
    private var averageScoreCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("30일 평균 생산성")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("\(Int(viewModel.averageScore * 100))점")
                    .font(.system(size: 40, weight: .bold))
            }
            Spacer()
            Circle()
                .trim(from: 0, to: viewModel.averageScore)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 60, height: 60)
                .animation(.easeOut(duration: 0.6), value: viewModel.averageScore)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 주간 생산성 추이
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("최근 7일 생산성", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            Chart(viewModel.weeklyData, id: \.date) { item in
                BarMark(
                    x: .value("날짜", item.date, unit: .day),
                    y: .value("점수", item.score * 100)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 요일별 평균
    private var weekdayChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("요일별 평균 생산성", systemImage: "calendar")
                .font(.headline)
            Chart(viewModel.weekdayData, id: \.weekday) { item in
                BarMark(
                    x: .value("요일", weekdayLabels[item.weekday]),
                    y: .value("점수", item.score * 100)
                )
                .foregroundStyle(Color.orange.gradient)
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 카테고리 분포
    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("업무 카테고리 분포", systemImage: "chart.pie")
                .font(.headline)
            Chart(viewModel.categoryData, id: \.category) { item in
                SectorMark(
                    angle: .value("횟수", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("카테고리", item.category))
                .cornerRadius(4)
            }
            .frame(height: 180)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 최근 하이라이트
    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("최근 하이라이트", systemImage: "star")
                .font(.headline)
            ForEach(viewModel.recentHighlights, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(item)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
