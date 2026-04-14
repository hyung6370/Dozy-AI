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

    func invalidateGoogleCache() {
        googleService.invalidateCache()
    }
    
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        var publishers: [AnyPublisher<[CalendarEvent], DozyError>] = []
        
        let appleEnabled = sourceManager.isEnabled(.apple)
        let googleEnabled = sourceManager.isEnabled(.google)

        if appleEnabled {
            publishers.append(appleService.fetchEvents(for: date))
        }
        if googleEnabled {
            publishers.append(
                googleService.fetchEvents(for: date)
                    .replaceError(with: []).setFailureType(to: DozyError.self).eraseToAnyPublisher()
            )
        }
        publishers.append(dozyService.fetchEvents(for: date))

        return Publishers.MergeMany(publishers)
            .collect()
            .map { arrays -> [CalendarEvent] in
                var all = arrays.flatMap { $0 }
                // Apple이 활성화된 경우 Google 공휴일 캘린더 이벤트 제외
                if appleEnabled && googleEnabled {
                    all = all.filter { event in
                        guard event.source == .google else { return true }
                        return !(event.calendarId?.contains("#holiday@group.v.calendar.google.com") ?? false)
                    }
                }
                var seen = Set<String>()
                var deduped: [CalendarEvent] = []
                // Dozy 이벤트는 항상 유지, Apple/Google 이벤트끼리만 중복 제거
                for event in all {
                    if event.source == .dozy {
                        deduped.append(event)
                    } else {
                        let cal = Calendar.current
                        let day = cal.startOfDay(for: event.startDate)
                        let key = "\(event.title.lowercased())_\(day.timeIntervalSince1970)"
                        if seen.insert(key).inserted {
                            deduped.append(event)
                        }
                    }
                }
                return deduped.sorted { $0.startDate < $1.startDate }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 날짜 범위 조회 (인사이트용)

    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        var publishers: [AnyPublisher<[CalendarEvent], DozyError>] = []

        let appleEnabled = sourceManager.isEnabled(.apple)
        let googleEnabled = sourceManager.isEnabled(.google)

        if appleEnabled {
            publishers.append(appleService.fetchEvents(from: start, to: end))
        }
        if googleEnabled {
            publishers.append(
                googleService.fetchEvents(from: start, to: end)
                    .replaceError(with: []).setFailureType(to: DozyError.self).eraseToAnyPublisher()
            )
        }
        publishers.append(dozyService.fetchEvents(from: start, to: end))

        return Publishers.MergeMany(publishers)
            .collect()
            .map { arrays -> [CalendarEvent] in
                var all = arrays.flatMap { $0 }
                // Apple이 활성화된 경우 Google 공휴일 캘린더 이벤트 제외
                if appleEnabled && googleEnabled {
                    all = all.filter { event in
                        guard event.source == .google else { return true }
                        return !(event.calendarId?.contains("#holiday@group.v.calendar.google.com") ?? false)
                    }
                }
                var seen = Set<String>()
                var deduped: [CalendarEvent] = []
                for event in all {
                    if event.source == .dozy {
                        deduped.append(event)
                    } else {
                        let cal = Calendar.current
                        let day = cal.startOfDay(for: event.startDate)
                        let key = "\(event.title.lowercased())_\(day.timeIntervalSince1970)"
                        if seen.insert(key).inserted {
                            deduped.append(event)
                        }
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
