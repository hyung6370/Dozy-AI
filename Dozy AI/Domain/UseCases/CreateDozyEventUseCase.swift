//
//  CreateDozyEventUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

final class CreateDozyEventUseCase {
    
    private let repository: DozyEventRepositoryProtocol
    private let analytics: AnalyticsServiceProtocol
    
    init(repository: DozyEventRepositoryProtocol, analytics: AnalyticsServiceProtocol = NoopAnalyticsService()) {
        self.repository = repository
        self.analytics = analytics
    }
    
    /// - Parameter method: 새 일정을 만든 방법. 저장이 성공하면 `event_created` 로 1회 보낸다 (#90).
    func execute(_ event: DozyEvent, method: EventInputMethod = .manual) -> AnyPublisher<Void, DozyError> {
        repository.save(event)
            .handleEvents(receiveOutput: { [analytics] in analytics.track(.eventCreated(method: method)) })
            .eraseToAnyPublisher()
    }
}
