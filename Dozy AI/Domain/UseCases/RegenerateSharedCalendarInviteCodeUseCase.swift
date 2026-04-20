//
//  RegenerateSharedCalendarInviteCodeUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class RegenerateSharedCalendarInviteCodeUseCase {
    private let service: SharedCalendarServiceProtocol

    init(service: SharedCalendarServiceProtocol) {
        self.service = service
    }

    func execute(calendarID: String) -> AnyPublisher<SharedCalendarInviteCodeResult, DozyError> {
        service.regenerateInviteCode(calendarID: calendarID)
    }
}
