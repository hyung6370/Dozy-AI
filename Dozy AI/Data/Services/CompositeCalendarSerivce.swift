//
//  CompositeCalendarSerivce.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation
import Combine

final class CompositeCalendarSerivce: CalendarServiceProtocol, CalendarWriteServiceProtocol {

    private let appleService: CalendarService
    private let googleService: GoogleCalendarService
    private let dozyService: DozyCalendarService
    let sourceManager: CalendarSourceManager

    init(
        appleService: CalendarService,
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
    
    // MARK: - CalendarWriteServiceProtocol
    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError> {
        switch event.source {
        case .apple: return appleService.updateEvent(event, with: edit)
        case .google: return googleService.updateEvent(event, with: edit)
        default: return Fail(error: .dataNotFound).eraseToAnyPublisher()
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError> {
        switch event.source {
        case .apple:  return appleService.deleteEvent(event)
        case .google: return googleService.deleteEvent(event)
        default:      return Fail(error: .dataNotFound).eraseToAnyPublisher()
        }
    }
}
