//
//  NaverCalendarService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/31/26.
//

import Foundation

final class NaverCalendarService: CalendarServiceProtocol {
    
    private let signInService: NaverSignInService
    private let baseURL = "https://openapi.naver.com/v1/calendar"
    
    init(signInService: NaverSignInService) {
        self.signInService = signInService
    }
    
    // MARK: - CalendarServiceProtocol

    func requestAccess() async throws(DozyError) -> Bool {
        signInService.isSignedIn
    }

    /// 실패는 빈 목록 (기존 Publisher 판의 replaceError 와 같음).
    func fetchEvents(for date: Date) async throws(DozyError) -> [CalendarEvent] {
        guard signInService.isSignedIn else { return [] }
        let token = try await signInService.getValidAccessToken()

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        guard var components = URLComponents(string: "\(baseURL)/get.json") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "startDt", value: fmt.string(from: date.startOfDay)),
            URLQueryItem(name: "endDt", value: fmt.string(from: date.startOfNextDay))
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(NaverCalendarResponse.self, from: data) else {
            return []
        }
    #if DEBUG
        print("[NaverCalendar] raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
    #endif
        return (decoded.calendars ?? []).flatMap { calendar in
            (calendar.schedules ?? []).compactMap {
                $0.toCalendarEvent(
                    calendarName: calendar.calendarName ?? "네이버 캘린더",
                    colorHex: "#03C75A"
                )
            }
        }
    }
}
