//
//  FetchDozyEventsForPeriodUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/2/26.
//

import Foundation
import Combine

final class FetchDozyEventsForPeriodUseCase {
    
    private let repository: DozyEventRepositoryProtocol
    
    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(from start: Date, to end: Date) -> AnyPublisher<[DozyEvent], DozyError> {
        repository.fetchEvents(from: start, to: end)
    }
}
