//
//  InsightDashboardViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/2/26.
//

import Foundation
import Combine

final class InsightDashboardViewModel: ObservableObject {
    
    @Published var weeklyData: [(date: Date, score: Double)] = []
    @Published var categoryData: [(category: String, count: Int)] = []
    @Published var weekdayData: [(weekday: Int, score: Double)] = []
    @Published var averageScore: Double = 0
    @Published var recentHighlights: [String] = []
    @Published var isLoading = false
    
    private let fetchRecentLogsUseCase: FetchRecentLogsUseCase
    private let patternService: PatternAnalysisService
    private var cancellables = Set<AnyCancellable>()
    
    init(fetchRecentLogsUseCase: FetchRecentLogsUseCase, patternService: PatternAnalysisService) {
        self.fetchRecentLogsUseCase = fetchRecentLogsUseCase
        self.patternService = patternService
    }
    
    func loadData() {
        isLoading = true
        fetchRecentLogsUseCase.execute(days: 30)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in self?.isLoading = false },
                receiveValue: { [weak self] logs in
                    guard let self else { return }
                    self.isLoading = false
                    self.weeklyData = self.patternService.weeklyProductivity(from: logs)
                    self.categoryData = self.patternService.categoryDistribution(from: logs)
                    self.weekdayData = self.patternService.weekdayAverageScore(from: logs)
                    self.averageScore = self.patternService.averageScore(from: logs)
                    self.recentHighlights = logs.suffix(7)
                        .flatMap(\.highlights)
                        .prefix(10)
                        .map { $0 }
                }
            )
            .store(in: &cancellables)
    }
}
