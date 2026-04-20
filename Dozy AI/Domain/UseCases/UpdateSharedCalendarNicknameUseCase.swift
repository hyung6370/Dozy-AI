//
//  UpdateSharedCalendarNicknameUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class UpdateSharedCalendarNicknameUseCase {
    private let service: SharedCalendarServiceProtocol

    init(service: SharedCalendarServiceProtocol) {
        self.service = service
    }

    func execute(calendarID: String, nickname: String) -> AnyPublisher<Void, DozyError> {
        service.updateNickname(calendarID: calendarID, nickname: nickname)
    }
}
