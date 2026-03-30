//
//  CompositeCalendarSerivce.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation
import Combine

final class CompositeCalendarSerivce: CalendarServiceProtocol {
    
    private let appleService: CalendarServiceProtocol
    private let googleService: GoogleCalendarService
    let sourceManager: CalendarSourceManager
    
    init(
        appleService: CalendarServiceProtocol,
        googleService: GoogleCalendarService,
        sourceManager: CalendarSourceManager
    ) {
        self.appleService  = appleService
        self.googleService = googleService
        self.sourceManager = sourceManager
    }
    
    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        appleService.requestAccess()
    }
    
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        var publishers: [AnyPublisher<[CalendarEvent], DozyError>] = []
        
        if sourceManager.isEnabled(.apple) {
            publishers.append(appleService.fetchEvents(for: date))
        }
        
        if sourceManager.isEnabled(.google) {
            // Google 실패는 무시하고 빈 배열 반환 (Apple 결과는 보존)
            let googlePublisher = googleService.fetchEvents(for: date)
                .replaceError(with: [])
                .setFailureType(to: DozyError.self)
                .eraseToAnyPublisher()
            publishers.append(googlePublisher)
        }
        
        guard !publishers.isEmpty else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { $0.flatMap { $0 }.sorted { $0.startDate < $1.startDate } }
            .eraseToAnyPublisher()
    }
}
