//
//  NaverCalendarService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/31/26.
//

import Foundation
import Combine

final class NaverCalendarService: CalendarServiceProtocol {
    
    private let signInService: NaverSignInService
    private let baseURL = "https://openapi.naver.com/v1/calendar"
    
    init(signInService: NaverSignInService) {
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
                return self.fetchNaverEvents(for: date, token: token)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private
    
    private func fetchNaverEvents(for date: Date, token: String) -> AnyPublisher<[CalendarEvent], DozyError> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        let startStr = fmt.string(from: date.startOfDay)
        let endStr = fmt.string(from: date.startOfNextDay)
        
        guard var components = URLComponents(string: "\(baseURL)/get.json") else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        components.queryItems = [
            URLQueryItem(name: "startDt", value: startStr),
            URLQueryItem(name: "endDt", value: endStr)
        ]
        guard let url = components.url else {
            return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> [CalendarEvent] in
#if DEBUG
                print("[NaverCalendar] raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
#endif
                
                let decoded = try JSONDecoder().decode(NaverCalendarResponse.self, from: data)
                return (decoded.calendars ?? []).flatMap { calendar in
                    (calendar.schedules ?? []).compactMap {
                        $0.toCalendarEvent(
                            calendarName: calendar.calendarName ?? "네이버 캘린더",
                            colorHex: "#03C75A"
                        )
                    }
                }
            }
            .replaceError(with: [])
            .setFailureType(to: DozyError.self)
            .eraseToAnyPublisher()
    }
}
