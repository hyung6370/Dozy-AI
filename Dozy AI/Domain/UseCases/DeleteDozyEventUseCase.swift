//
//  DeleteDozyEventUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

final class DeleteDozyEventUseCase {
    
    private let repository: DozyEventRepositoryProtocol
    
    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        repository.delete(event)
    }
}
