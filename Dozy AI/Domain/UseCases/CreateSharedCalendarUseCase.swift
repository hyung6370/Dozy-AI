//
//  CreateSharedCalendarUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class CreateSharedCalendarUseCase {
    private let service: SharedCalendarServiceProtocol

    init(service: SharedCalendarServiceProtocol) {
        self.service = service
    }

    func execute(name: String) -> AnyPublisher<SharedCalendarCreationResult, DozyError> {
        service.create(name: name)
    }
}
