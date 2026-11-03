//
//  CalendarWriteServiceProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

protocol CalendarWriteServiceProtocol {
    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) async throws(DozyError)
    func deleteEvent(_ event: CalendarEvent) async throws(DozyError)
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)

extension CalendarWriteServiceProtocol {
    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.updateEvent(event, with: edit) }
    }

    func deleteEvent(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.deleteEvent(event) }
    }
}
