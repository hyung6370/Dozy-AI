//
//  DeleteCalendarEventUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

final class DeleteCalendarEventUseCase {
    private let service: CalendarWriteServiceProtocol

    init(service: CalendarWriteServiceProtocol) {
        self.service = service
    }
    
    func execute(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError> {
        service.deleteEvent(event)
    }
}
