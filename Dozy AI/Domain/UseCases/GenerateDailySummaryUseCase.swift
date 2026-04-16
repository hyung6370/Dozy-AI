//
//  GenerateDailySummaryUseCase.swift
//  Dozy AI
//
//  [Clean Architecture - UseCase]
//  AI 요약 생성 + 결과를 WorkLog에 저장하는 비즈니스 로직을 캡슐화합니다.
//  1. AIService로 DailySummary 생성
//  2. 오늘 WorkLog에 결과 반영 후 저장
//  3. DailySummary 반환

import Foundation
import Combine

final class GenerateDailySummaryUseCase {

    private let aiService: AIServiceProtocol
    private let repository: WorkLogRepositoryProtocol

    init(aiService: AIServiceProtocol, repository: WorkLogRepositoryProtocol) {
        self.aiService = aiService
        self.repository = repository
    }

    /// AI 요약을 생성하고, 오늘 WorkLog에 저장한 뒤 DailySummary를 반환합니다
    func execute(
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String],
        completedEventCount: Int = 0
    ) -> AnyPublisher<DailySummary, DozyError> {

        aiService.generateDailySummary(
            events: events,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            memos: memos,
            completedEventCount: completedEventCount
        )
        .flatMap { [repository] summary -> AnyPublisher<DailySummary, DozyError> in
            // 오늘 WorkLog에 AI 결과를 저장 (없으면 저장 생략하고 summary만 반환)
            repository.fetchLog(for: Date())
                .flatMap { existingLog -> AnyPublisher<DailySummary, DozyError> in
                    guard let log = existingLog else {
                        return Just(summary)
                            .setFailureType(to: DozyError.self)
                            .eraseToAnyPublisher()
                    }
                    summary.apply(to: log)
                    return repository.save(log)
                        .map { summary }
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
