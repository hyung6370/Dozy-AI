//
//  CreateSharedCalendarUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class CreateSharedCalendarUseCase {
    private let service: SharedCalendarServiceProtocol
    private let analytics: AnalyticsServiceProtocol

    init(service: SharedCalendarServiceProtocol, analytics: AnalyticsServiceProtocol = NoopAnalyticsService()) {
        self.service = service
        self.analytics = analytics
    }

    func execute(name: String) -> AnyPublisher<SharedCalendarCreationResult, DozyError> {
        service.create(name: name)
            .handleEvents(receiveOutput: { [analytics] _ in analytics.track(.sharedCalendarCreated) })
            .eraseToAnyPublisher()
    }
}
