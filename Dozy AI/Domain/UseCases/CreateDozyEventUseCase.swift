//
//  CreateDozyEventUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

final class CreateDozyEventUseCase {
    
    private let repository: DozyEventRepositoryProtocol
    
    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        repository.save(event)
    }
}
