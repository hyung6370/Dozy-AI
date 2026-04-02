//
//  ToggleDozyEventCompletionUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

final class ToggleDozyEventCompletionUseCase {
    
    private let repository: DozyEventRepositoryProtocol
    
    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        event.isCompleted.toggle()
        return repository.update(event)
    }
}
