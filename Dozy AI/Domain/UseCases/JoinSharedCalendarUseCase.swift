//
//  JoinSharedCalendarUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class JoinSharedCalendarUseCase {
    private let service: SharedCalendarServiceProtocol

    init(service: SharedCalendarServiceProtocol) {
        self.service = service
    }

    func execute(inviteCode: String) -> AnyPublisher<SharedCalendarJoinResult, DozyError> {
        service.join(inviteCode: inviteCode)
    }
}
