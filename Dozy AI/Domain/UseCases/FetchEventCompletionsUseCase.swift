//
//  FetchEventCompletionsUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

final class FetchEventCompletionsUseCase {
    private let repository: EventCompletionRepositoryProtocol
    
    init(repository: EventCompletionRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(for eventIDs: [String], on date: Date) -> AnyPublisher<[String: Bool], DozyError> {
        repository.fetchCompletions(for: eventIDs, on: date)
    }
}
