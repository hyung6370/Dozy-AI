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
    private let dozyService: DozyCalendarService
    let sourceManager: CalendarSourceManager
    
    init(
        appleService: CalendarServiceProtocol,
        googleService: GoogleCalendarService,
        dozyService: DozyCalendarService,
        sourceManager: CalendarSourceManager
    ) {
        self.appleService = appleService
        self.googleService = googleService
        self.dozyService = dozyService
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
            publishers.append(
                googleService.fetchEvents(for: date)
                    .replaceError(with: []).setFailureType(to: DozyError.self).eraseToAnyPublisher()
            )
        }
        
        publishers.append(dozyService.fetchEvents(for: date))
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { $0.flatMap { $0 }.sorted { $0.startDate < $1.startDate } }
            .eraseToAnyPublisher()
    }
}
