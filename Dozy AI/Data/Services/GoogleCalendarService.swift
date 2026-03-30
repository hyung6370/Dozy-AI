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
    
    init(signInService: GoogleSignInService) {
        self.signInService = signInService
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
        
        return signInService.getValidAccessToken()
            .flatMap { [weak self] token -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.fetchAllEvents(for: date, token: token)
            }
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
                        colorHex: calendar.backgroundColor ?? "#4285F4"
                    )
                }
            }
            .replaceError(with: [])
            .setFailureType(to: DozyError.self)
            .eraseToAnyPublisher()
    }
}
