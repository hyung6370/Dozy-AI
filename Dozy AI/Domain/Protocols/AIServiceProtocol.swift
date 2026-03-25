//
//  AIServiceProtocol.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine

protocol AIServiceProtocol {
    
    /// 일일 요약 생성 (async)
    func generateDailySummary(
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String]
    ) async throws -> DailySummary
    
    /// 빠른 한줄 요약 (위젯, Siri용)
    func generateQuickSummary(
        events: [CalendarEvent],
        completedTasks: [TaskItem]
    ) async throws -> String
}


// async 메서드만 구현하면 Combine 버전이 자동으로 생기도록
// default implementation을 제공한다
// 이러면 구현체(AIService)에서는 async 버전만 작성하면 된다
extension AIServiceProtocol {
    
    func generateDailySummary(
        events: [CalendarEvent],
        completedTasks: [TaskItem],
        pendingTasks: [TaskItem],
        memos: [String]
    ) -> AnyPublisher<DailySummary, DozyError> {
        Future { promise in
            Task {
                do {
                    let summary = try await self.generateDailySummary(
                        events: events,
                        completedTasks: completedTasks,
                        pendingTasks: pendingTasks,
                        memos: memos
                    )
                    promise(.success(summary))
                } catch let error as DozyError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(.aiSummarizationFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
