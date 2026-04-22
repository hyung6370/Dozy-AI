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
                return Self.dedupe(all)
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
                return Self.dedupe(all)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Dedupe

    /// - Apple↔Google 간 동일 시각·제목 중복 제거 (동기화된 동일 이벤트)
    /// - 내 기기에 Apple/Google 원본이 있으면 동일 (externalSource, externalEventID)를 가진
    ///   Dozy 미러 스냅샷은 제거 → 원본 편집권을 유지하고 리스트 중복도 방지.
    ///   파트너 기기에서는 원본이 없으니 스냅샷만 그대로 표시된다.
    private static func dedupe(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var localOrigins: Set<String> = []
        for event in events where event.source == .apple || event.source == .google {
            localOrigins.insert("\(event.source.rawValue)_\(event.id)")
        }

        var seen = Set<String>()
        var deduped: [CalendarEvent] = []
        for event in events {
            if event.source == .dozy {
                if let src = event.externalSource?.rawValue,
                   let extID = event.externalEventID,
                   localOrigins.contains("\(src)_\(extID)") {
                    continue
                }
                deduped.append(event)
            } else {
                let key = "\(event.title.lowercased())_\(event.startDate.timeIntervalSince1970)"
                if seen.insert(key).inserted {
                    deduped.append(event)
                }
            }
        }
        return deduped.sorted { $0.startDate < $1.startDate }
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
