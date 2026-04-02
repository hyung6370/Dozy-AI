//
//  CalendarWriteServiceProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

protocol CalendarWriteServiceProtocol {
    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError>
    func deleteEvent(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError>
}
