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
    func fetchCompletions(for eventIDs: [String], on date: Date) -> AnyPublisher<[String: Bool], DozyError>
    func fetchCompletions(from start: Date, to end: Date) -> AnyPublisher<[EventCompletion], DozyError>
    func toggle(eventID: String, eventDate: Date) -> AnyPublisher<Bool, DozyError>
}
