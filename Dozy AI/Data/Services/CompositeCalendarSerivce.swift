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
            .map { arrays -> [CalendarEvent] in
                let all = arrays.flatMap { $0 }
                var seen = Set<String>()
                var deduped: [CalendarEvent] = []
                // apple → google → dozy 순으로 처리해 Apple 이벤트를 우선 유지
                let ordered = all.sorted { lhs, rhs in
                    let priority: (CalendarSource) -> Int = {
                        switch $0 { case .apple: return 0; case .dozy: return 1; default: return 2 }
                    }
                    return priority(lhs.source) < priority(rhs.source)
                }
                for event in ordered {
                    let cal = Calendar.current
                    let day = cal.startOfDay(for: event.startDate)
                    let key = "\(event.title.lowercased())_\(day.timeIntervalSince1970)"
                    if seen.insert(key).inserted {
                        deduped.append(event)
                    }
                }
                return deduped.sorted { $0.startDate < $1.startDate }
            }
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
