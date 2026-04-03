//
//  FetchEventCompletionsForPeriodUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class FetchEventCompletionsForPeriodUseCase {
    private let repository: EventCompletionRepositoryProtocol

    init(repository: EventCompletionRepositoryProtocol) {
        self.repository = repository
    }

    func execute(from start: Date, to end: Date) -> AnyPublisher<[EventCompletion], DozyError> {
        repository.fetchCompletions(from: start, to: end)
    }
}
