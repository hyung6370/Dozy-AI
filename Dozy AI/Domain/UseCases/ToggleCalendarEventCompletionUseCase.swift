//
//  ToggleCalendarEventCompletionUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

final class ToggleCalendarEventCompletionUseCase {
    private let repository: EventCompletionRepositoryProtocol
    
    init(repository: EventCompletionRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(eventID: String, eventDate: Date) -> AnyPublisher<Bool, DozyError> {
        repository.toggle(eventID: eventID, eventDate: eventDate)
    }
}
