//
//  EventCompletionRepositoryProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

protocol EventCompletionRepositoryProtocol {
    func fetchCompletions(for eventIDs: [String]) -> AnyPublisher<[String: Bool], DozyError>
    func toggle(eventID: String) -> AnyPublisher<Bool, DozyError>
}
