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
    private var cache: [Date: CacheEntry] = [:]           // 일별 캐시
    private var rangeCache: [String: CacheEntry] = [:]    // 범위 캐시
    private var calendarListCache: (items: [GoogleCalendarItem], fetchedAt: Date)?
    private let cacheTTL: TimeInterval = 5 * 60           // 5분
    private let calendarListTTL: TimeInterval = 15 * 60   // 15분

    init(signInService: GoogleSignInService) {
        self.signInService = signInService
    }

    func invalidateCache(for date: Date? = nil) {
        if let date {
            cache.removeValue(forKey: Calendar.current.startOfDay(for: date))
            rangeCache.removeAll() // 날짜 범위 캐시도 무효화
        } else {
            cache.removeAll()
            rangeCache.removeAll()
            calendarListCache = nil
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
        let key = "\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))"
        if let entry = rangeCache[key], Date().timeIntervalSince(entry.fetchedAt) < cacheTTL {
            return Just(entry.events).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        return signInService.getValidAccessToken()
            .flatMap { [weak self] token -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.fetchAllEvents(from: start, to: end, token: token)
            }
            .handleEvents(receiveOutput: { [weak self] events in
                self?.rangeCache[key] = CacheEntry(events: events, fetchedAt: Date())
            })
            .eraseToAnyPublisher()
    }

    private func fetchAllEvents(from start: Date, to end: Date, token: String) -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchCalendarList(token: token)
            .flatMap { [weak self] calendars -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                let active = calendars.filter { $0.selected != false && !Self.isHolidayCalendar($0) }
                guard !active.isEmpty else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                // 단일 캘린더는 직접 조회, 복수 캘린더는 Batch API로 1회 HTTP 요청
                if active.count == 1 {
                    return self.fetchEvents(from: active[0], from: start, to: end, token: token)
                }
                return self.batchFetchEvents(calendars: active, from: start, to: end, token: token)
                    .catch { [weak self] _ -> AnyPublisher<[CalendarEvent], DozyError> in
                        guard let self else {
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
            .eraseToAnyPublisher()
    }

    // MARK: - Google Batch API (N개 캘린더 이벤트를 1회 HTTP 요청으로 처리)

    private func batchFetchEvents(
        calendars: [GoogleCalendarItem],
        from start: Date,
        to end: Date,
        token: String
    ) -> AnyPublisher<[CalendarEvent], DozyError> {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let timeMin = iso.string(from: start)
        let timeMax = iso.string(from: end)
        let boundary = "batch_dozy_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))"

        var body = ""
        for (index, cal) in calendars.enumerated() {
            let encodedId = cal.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cal.id
            let qs = [
                "timeMin=\(timeMin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                "timeMax=\(timeMax.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                "singleEvents=true", "orderBy=startTime", "maxResults=2500"
            ].joined(separator: "&")
            body += "--\(boundary)\r\n"
            body += "Content-Type: application/http\r\n"
            body += "Content-ID: <cal-\(index)>\r\n\r\n"
            body += "GET /calendar/v3/calendars/\(encodedId)/events?\(qs) HTTP/1.1\r\n\r\n"
        }
        body += "--\(boundary)--"

        guard let url = URL(string: "https://www.googleapis.com/batch/calendar/v3") else {
            return Fail(error: .googleCalendarFetchFailed).eraseToAnyPublisher()
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/mixed; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)

        return URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { [calendars] data, response -> [CalendarEvent] in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let ct = http.allHeaderFields["Content-Type"] as? String else {
                    throw DozyError.googleCalendarFetchFailed
                }
                return Self.parseBatchResponse(data: data, contentType: ct, calendars: calendars)
            }
            .mapError { ($0 as? DozyError) ?? .googleCalendarFetchFailed }
            .eraseToAnyPublisher()
    }

    private static func parseBatchResponse(
        data: Data,
        contentType: String,
        calendars: [GoogleCalendarItem]
    ) -> [CalendarEvent] {
        guard let boundaryValue = contentType
                .components(separatedBy: "boundary=").last?
                .components(separatedBy: ";").first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) else { return [] }
        let boundary = "--" + boundaryValue
        guard let responseStr = String(data: data, encoding: .utf8) else { return [] }

        var allEvents: [CalendarEvent] = []
        let decoder = JSONDecoder()

        for part in responseStr.components(separatedBy: boundary) {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "--" else { continue }

            // Content-ID: <response-cal-N> → extract index N
            var calIndex: Int? = nil
            for line in part.components(separatedBy: "\r\n") {
                guard line.lowercased().hasPrefix("content-id:") else { continue }
                let val = line.dropFirst(11).trimmingCharacters(in: .whitespaces)
                let inner = val.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                    .replacingOccurrences(of: "response-", with: "")
                    .components(separatedBy: ":").first ?? ""
                if inner.hasPrefix("cal-"), let idx = Int(inner.dropFirst(4)) {
                    calIndex = idx
                }
                break
            }

            // HTTP 상태 확인 (두 번째 줄 = HTTP 응답 상태)
            var isOK = false
            let partLines = part.components(separatedBy: "\r\n")
            for line in partLines {
                if line.hasPrefix("HTTP/") {
                    isOK = line.contains(" 200 ") || line.contains(" 2")
                    break
                }
            }
            guard isOK else { continue }

            // JSON 본문: 두 번째 \r\n\r\n 이후
            var count = 0
            var jsonStart: String.Index? = nil
            var searchFrom = part.startIndex
            while let range = part.range(of: "\r\n\r\n", range: searchFrom..<part.endIndex) {
                count += 1
                if count == 2 { jsonStart = range.upperBound; break }
                searchFrom = range.upperBound
            }
            guard let js = jsonStart else { continue }
            let jsonStr = String(part[js...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !jsonStr.isEmpty,
                  let jsonData = jsonStr.data(using: .utf8),
                  let resp = try? decoder.decode(GoogleEventsResponse.self, from: jsonData) else { continue }

            let cal = calIndex.flatMap { $0 < calendars.count ? calendars[$0] : nil }
            let events = (resp.items ?? []).compactMap {
                $0.toCalendarEvent(
                    calendarName: cal?.summary ?? "Google Calendar",
                    colorHex: cal?.backgroundColor ?? "#4285F4",
                    calendarId: cal?.id ?? ""
                )
            }
            allEvents.append(contentsOf: events)
        }

        return allEvents.sorted { $0.startDate < $1.startDate }
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

    /// Google 의 시스템 휴일 캘린더 (한국 공휴일 등) 식별. Dozy 는 자체 공공데이터포털
    /// 데이터로 공휴일을 노출하므로 Google 휴일 캘린더는 중복 표시 방지를 위해 제외.
    /// ID 패턴 예: `ko.south_korea#holiday@group.v.calendar.google.com`
    /// 더불어 Birthdays 캘린더 (`addressbook#contacts@group.v.calendar.google.com`) 도
    /// 사용자 일정과 무관해서 함께 제외.
    private static func isHolidayCalendar(_ cal: GoogleCalendarItem) -> Bool {
        cal.id.contains("#holiday@") || cal.id.contains("addressbook#contacts@")
    }

    private func fetchAllEvents(for date: Date, token: String) -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchCalendarList(token: token)
            .flatMap { [weak self] calendars -> AnyPublisher<[CalendarEvent], DozyError> in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                let active = calendars.filter { $0.selected != false && !Self.isHolidayCalendar($0) }
                guard !active.isEmpty else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                if active.count == 1 {
                    return self.fetchEvents(from: active[0], for: date, token: token)
                }
                return self.batchFetchEvents(
                    calendars: active, from: date.startOfDay, to: date.startOfNextDay, token: token
                )
                .catch { [weak self] _ -> AnyPublisher<[CalendarEvent], DozyError> in
                    guard let self else {
                        return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                    }
                    return Publishers.MergeMany(active.map { self.fetchEvents(from: $0, for: date, token: token) })
                        .collect()
                        .map { $0.flatMap { $0 }.sorted { $0.startDate < $1.startDate } }
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchCalendarList(token: String) -> AnyPublisher<[GoogleCalendarItem], DozyError> {
        if let cached = calendarListCache,
           Date().timeIntervalSince(cached.fetchedAt) < calendarListTTL {
            return Just(cached.items).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
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
            .handleEvents(receiveOutput: { [weak self] items in
                self?.calendarListCache = (items: items, fetchedAt: Date())
            })
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
