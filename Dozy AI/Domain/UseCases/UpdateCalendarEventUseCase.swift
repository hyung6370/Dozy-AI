//
//  UpdateCalendarEventUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

final class UpdateCalendarEventUseCase {
    private let service: CalendarWriteServiceProtocol
    init(service: CalendarWriteServiceProtocol) {
        self.service = service
    }
    
    func execute(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError> {
        service.updateEvent(event, with: edit)
    }
}
