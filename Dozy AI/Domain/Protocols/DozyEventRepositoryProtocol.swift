//
//  DozyEventRepositoryProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

protocol DozyEventRepositoryProtocol {
    func fetchEvents(from: Date, to: Date) -> AnyPublisher<[DozyEvent], DozyError>
    func save(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>
    func update(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>
    func delete(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>
}
