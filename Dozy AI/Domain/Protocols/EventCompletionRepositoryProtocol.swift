//
//  EventCompletionRepositoryProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

protocol EventCompletionRepositoryProtocol {
    // key: "\(eventID)_\(startOfDay timestamp)" 복합키 반환
    func fetchCompletions(for eventIDs: [String], on date: Date) async throws(DozyError) -> [String: Bool]
    func fetchCompletions(from start: Date, to end: Date) async throws(DozyError) -> [EventCompletion]
    func toggle(eventID: String, eventDate: Date) async throws(DozyError) -> Bool
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)

extension EventCompletionRepositoryProtocol {
    func fetchCompletions(for eventIDs: [String], on date: Date) -> AnyPublisher<[String: Bool], DozyError> {
        .bridge { () async throws(DozyError) -> [String: Bool] in try await self.fetchCompletions(for: eventIDs, on: date) }
    }

    func fetchCompletions(from start: Date, to end: Date) -> AnyPublisher<[EventCompletion], DozyError> {
        .bridge { () async throws(DozyError) -> [EventCompletion] in try await self.fetchCompletions(from: start, to: end) }
    }

    func toggle(eventID: String, eventDate: Date) -> AnyPublisher<Bool, DozyError> {
        .bridge { () async throws(DozyError) -> Bool in try await self.toggle(eventID: eventID, eventDate: eventDate) }
    }
}
