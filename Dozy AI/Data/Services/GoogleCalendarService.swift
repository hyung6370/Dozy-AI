//
//  GoogleCalendarService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation
import Combine

final class GoogleCalendarService: CalendarServiceProtocol {

    private let signInService: GoogleSignInService
    private let baseURL = "https://www.googleapis.com/calendar/v3"

    private struct CacheEntry {
        let events: [CalendarEvent]
        let fetchedAt: Date
    }
    private var cache: [Date: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes

    init(signInService: GoogleSignInService) {
        self.signInService = signInService
    }

    func invalidateCache(for date: Date? = nil) {
        if let date {
            cache.removeValue(forKey: Calendar.current.startOfDay(for: date))
        } else {
            cache.removeAll()
        }
    }
    
    // MARK: - CalendarServiceProtocol
    
    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        Just(signInService.isSignedIn)
            .setFailureType(to: DozyError.self)
            .eraseToAnyPublisher()
    }
    
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        guard signInService.isSignedIn else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }

        let key = Calendar.current.startOfDay(for: date)
        if let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < cacheTTL {
            return Just(entry.events).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }

        return signInService.getValidAccessToken()
            .flatMap { [weak self] token -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.fetchAllEvents(for: date, token: token)
            }
            .handleEvents(receiveOutput: { [weak self] events in
                self?.cache[key] = CacheEntry(events: events, fetchedAt: Date())
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - 날짜 범위 조회 (인사이트용 — 단일 API 호출로 효율적)

    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        guard signInService.isSignedIn else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        return signInService.getValidAccessToken()
            .flatMap { [weak self] token -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.fetchAllEvents(from: start, to: end, token: token)
            }
            .eraseToAnyPublisher()
    }

    private func fetchAllEvents(from start: Date, to end: Date, token: String) -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchCalendarList(token: token)
            .flatMap { [weak self] calendars -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                let active = calendars.filter { $0.selected != false }
                guard !active.isEmpty else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                let publishers = active.map { cal in
                    self.fetchEvents(from: cal, from: start, to: end, token: token)
                }
                return Publishers.MergeMany(publishers)
                    .collect()
                    .map { $0.flatMap { $0 }.sorted { $0.startDate < $1.startDate } }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func fetchEvents(from calendar: GoogleCalendarItem, from start: Date, to end: Date, token: String) -> AnyPublisher<[CalendarEvent], DozyError> {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timeMin = formatter.string(from: start)
        let timeMax = formatter.string(from: end)
        let encodedId = calendar.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendar.id
        guard var components = URLComponents(string: "\(baseURL)/calendars/\(encodedId)/events") else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "2500")
        ]
        guard let url = components.url else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> [CalendarEvent] in
                let decoded = try JSONDecoder().decode(GoogleEventsResponse.self, from: data)
                return (decoded.items ?? []).compactMap {
                    $0.toCalendarEvent(
                        calendarName: calendar.summary,
                        colorHex: calendar.backgroundColor ?? "#4285F4",
                        calendarId: calendar.id
                    )
                }
            }
            .replaceError(with: [])
            .setFailureType(to: DozyError.self)
            .eraseToAnyPublisher()
    }

    // MARK: - Private
    private func fetchAllEvents(for date: Date, token: String) -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchCalendarList(token: token)
            .flatMap { [weak self] calendars -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                
                let active = calendars.filter { $0.selected != false }
                guard !active.isEmpty else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                
                let publishers = active.map { cal in
                    self.fetchEvents(from: cal, for: date, token: token)
                }
                
                return Publishers.MergeMany(publishers)
                    .collect()
                    .map { $0.flatMap { $0 }.sorted { $0.startDate < $1.startDate } }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchCalendarList(token: String) -> AnyPublisher<[GoogleCalendarItem], DozyError> {
        guard let url = URL(string: "\(baseURL)/users/me/calendarList") else {
            return Fail(error: .googleCalendarFetchFailed).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> [GoogleCalendarItem] in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw DozyError.googleCalendarFetchFailed
                }
                let decoded = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
                return decoded.items ?? []
            }
            .mapError { ($0 as? DozyError) ?? .googleCalendarFetchFailed }
            .eraseToAnyPublisher()
    }
    
    private func fetchEvents(from calendar: GoogleCalendarItem, for date: Date, token: String) -> AnyPublisher<[CalendarEvent], DozyError> {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let timeMin = formatter.string(from: date.startOfDay)
        let timeMax = formatter.string(from: date.startOfNextDay)
        let encodedId = calendar.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendar.id
        
        guard var components = URLComponents(string: "\(baseURL)/calendars/\(encodedId)/events") else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "50")
        ]
        guard let url = components.url else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> [CalendarEvent] in
                let decoded = try JSONDecoder().decode(GoogleEventsResponse.self, from: data)
                return (decoded.items ?? []).compactMap {
                    $0.toCalendarEvent(
                        calendarName: calendar.summary,
                        colorHex: calendar.backgroundColor ?? "#4285F4",
                        calendarId: calendar.id
                    )
                }
            }
            .replaceError(with: [])
            .setFailureType(to: DozyError.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - CalendarWriteServiceProtocol
extension GoogleCalendarService: CalendarWriteServiceProtocol {
    
    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError> {
        guard signInService.isSignedIn, let calendarId = event.calendarId else {
            return Fail(error: .dataNotFound).eraseToAnyPublisher()
        }
        return signInService.getValidAccessToken()
            .flatMap { [weak self] token -> AnyPublisher<Void, DozyError> in
                guard let self else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }
                return self.patchEvent(event: event, edit: edit, calendarId: calendarId, token: token)
            }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.invalidateCache(for: event.startDate)
            })
            .eraseToAnyPublisher()
    }

    func deleteEvent(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError> {
        guard signInService.isSignedIn, let calendarId = event.calendarId else {
            return Fail(error: .dataNotFound).eraseToAnyPublisher()
        }
        return signInService.getValidAccessToken()
            .flatMap { [weak self] token -> AnyPublisher<Void, DozyError> in
                guard let self else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }
                return self.deleteEventRequest(eventId: event.id, calendarId: calendarId, token: token)
            }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.invalidateCache(for: event.startDate)
            })
            .eraseToAnyPublisher()
    }
    
    private func patchEvent(event: CalendarEvent, edit: CalendarEventEditRequest,
                            calendarId: String, token: String) -> AnyPublisher<Void, DozyError> {
        let encCal = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let encEvt = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.id
        guard let url = URL(string: "\(baseURL)/calendars/\(encCal)/events/\(encEvt)") else {
            return Fail(error: .googleCalendarFetchFailed).eraseToAnyPublisher()
        }
        
        var body: [String: Any] = ["summary": edit.title]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        
        if edit.isAllDay {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            body["start"] = ["date": fmt.string(from: edit.startDate)]
            body["end"]   = ["date": fmt.string(from: edit.endDate)]
        } else {
            let tz = TimeZone.current.identifier
            body["start"] = ["dateTime": iso.string(from: edit.startDate), "timeZone": tz]
            body["end"]   = ["dateTime": iso.string(from: edit.endDate),   "timeZone": tz]
        }
        if let loc  = edit.location { body["location"]    = loc }
        if let note = edit.notes    { body["description"] = note }
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { _, response in
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw DozyError.googleCalendarFetchFailed
                }
            }
            .mapError { ($0 as? DozyError) ?? .googleCalendarFetchFailed }
            .eraseToAnyPublisher()
    }
    
    private func deleteEventRequest(eventId: String, calendarId: String, token: String) -> AnyPublisher<Void, DozyError> {
        let encCal = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let encEvt = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        guard let url = URL(string: "\(baseURL)/calendars/\(encCal)/events/\(encEvt)") else {
            return Fail(error: .googleCalendarFetchFailed).eraseToAnyPublisher()
        }

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { _, response in
                guard let http = response as? HTTPURLResponse else {
                    throw DozyError.googleCalendarFetchFailed
                }
                guard http.statusCode == 204 else {
                    throw DozyError.googleCalendarWriteFailed(statusCode: http.statusCode)
                }
            }
            .mapError { ($0 as? DozyError) ?? .googleCalendarFetchFailed }
            .eraseToAnyPublisher()
    }
}
