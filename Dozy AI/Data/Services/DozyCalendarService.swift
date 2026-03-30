//
//  DozyCalendarService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

// [Data Layer] DozyEvent -> CalendarEvent 변환 서비스
// CompositeCalendarService에서 항상 포함된다

final class DozyCalendarService: CalendarServiceProtocol {
    
    private let repository: DozyEventRepositoryProtocol
    
    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }
    
    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        Just(true).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
    
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        repository.fetchEvents(from: date.startOfDay, to: date.startOfNextDay)
            .map { $0.map { $0.toCalendarEvent() } }
            .eraseToAnyPublisher()
    }
}
