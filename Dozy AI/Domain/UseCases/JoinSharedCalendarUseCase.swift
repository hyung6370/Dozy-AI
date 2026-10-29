//
//  JoinSharedCalendarUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class JoinSharedCalendarUseCase {
    private let service: SharedCalendarServiceProtocol
    private let analytics: AnalyticsServiceProtocol

    init(service: SharedCalendarServiceProtocol, analytics: AnalyticsServiceProtocol = NoopAnalyticsService()) {
        self.service = service
        self.analytics = analytics
    }

    /// - Parameter via: 초대 코드를 직접 입력했는지, 초대 링크로 열렸는지 (#90).
    func execute(inviteCode: String, via: SharedCalendarJoinVia = .code) -> AnyPublisher<SharedCalendarJoinResult, DozyError> {
        service.join(inviteCode: inviteCode)
            .handleEvents(receiveOutput: { [analytics] _ in analytics.track(.sharedCalendarJoined(via: via)) })
            .eraseToAnyPublisher()
    }
}
