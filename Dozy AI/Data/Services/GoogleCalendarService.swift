//
//  GoogleCalendarService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation

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

    // 캐시 딕셔너리는 메인(읽기)과 URLSession 백그라운드 큐(handleEvents 쓰기) 양쪽에서
    // 접근되므로 반드시 락으로 직렬화한다. (캘린더 탭 재진입 시 당일+현재월+인접월
    // fetch 가 동시 팬아웃 → 여러 백그라운드 스레드가 같은 Dictionary 에 동시 쓰기 →
    // 힙 손상/EXC_BAD_ACCESS 크래시가 발생하던 문제 차단)
    private let cacheLock = NSLock()

    private func withCacheLock<T>(_ body: () -> T) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return body()
    }

    init(signInService: GoogleSignInService) {
        self.signInService = signInService
    }

    func invalidateCache(for date: Date? = nil) {
        withCacheLock {
            if let date {
                cache.removeValue(forKey: Calendar.current.startOfDay(for: date))
                rangeCache.removeAll() // 날짜 범위 캐시도 무효화
            } else {
                cache.removeAll()
                rangeCache.removeAll()
                calendarListCache = nil
            }
        }
    }
    
    // MARK: - CalendarServiceProtocol

    func requestAccess() async throws(DozyError) -> Bool {
        signInService.isSignedIn
    }

    func fetchEvents(for date: Date) async throws(DozyError) -> [CalendarEvent] {
        guard signInService.isSignedIn else { return [] }

        let key = Calendar.current.startOfDay(for: date)
        if let entry = withCacheLock({ cache[key] }), Date().timeIntervalSince(entry.fetchedAt) < cacheTTL {
            return entry.events
        }
        let token = try await signInService.getValidAccessToken()
        let events = try await fetchAllEvents(from: date.startOfDay, to: date.startOfNextDay, maxResults: 50, token: token)
        withCacheLock { cache[key] = CacheEntry(events: events, fetchedAt: Date()) }
        return events
    }

    // MARK: - 날짜 범위 조회 (인사이트용 — 단일 API 호출로 효율적)

    func fetchEvents(from start: Date, to end: Date) async throws(DozyError) -> [CalendarEvent] {
        guard signInService.isSignedIn else { return [] }
        let key = "\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))"
        if let entry = withCacheLock({ rangeCache[key] }), Date().timeIntervalSince(entry.fetchedAt) < cacheTTL {
            return entry.events
        }
        let token = try await signInService.getValidAccessToken()
        let events = try await fetchAllEvents(from: start, to: end, maxResults: 2500, token: token)
        withCacheLock { rangeCache[key] = CacheEntry(events: events, fetchedAt: Date()) }
        return events
    }

    /// 단일 캘린더는 직접 조회, 복수 캘린더는 Batch API 로 1회 HTTP 요청 — 배치가 실패하면 캘린더별로 다시 조회한다.
    /// (하루 조회 · 범위 조회가 maxResults 만 다르던 두 경로를 하나로 합쳤다.)
    private func fetchAllEvents(from start: Date, to end: Date, maxResults: Int, token: String) async throws(DozyError) -> [CalendarEvent] {
        let calendars = try await fetchCalendarList(token: token)
        let active = calendars.filter { $0.selected != false && !Self.isHolidayCalendar($0) }
        guard !active.isEmpty else { return [] }
        if active.count == 1 {
            return await fetchEvents(from: active[0], from: start, to: end, maxResults: maxResults, token: token)
        }
        do throws(DozyError) {
            return try await batchFetchEvents(calendars: active, from: start, to: end, token: token)
        } catch {
            var all: [CalendarEvent] = []
            for calendar in active {
                all += await fetchEvents(from: calendar, from: start, to: end, maxResults: maxResults, token: token)
            }
            return all.sorted { $0.startDate < $1.startDate }
        }
    }

    // MARK: - Google Batch API (N개 캘린더 이벤트를 1회 HTTP 요청으로 처리)

    private func batchFetchEvents(
        calendars: [GoogleCalendarItem],
        from start: Date,
        to end: Date,
        token: String
    ) async throws(DozyError) -> [CalendarEvent] {
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
            throw .googleCalendarFetchFailed
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/mixed; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let ct = http.allHeaderFields["Content-Type"] as? String else {
            throw .googleCalendarFetchFailed
        }
        return Self.parseBatchResponse(data: data, contentType: ct, calendars: calendars)
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

    /// 캘린더 하나의 이벤트. 실패는 빈 목록 (기존 Publisher 판의 replaceError 와 같음).
    private func fetchEvents(from calendar: GoogleCalendarItem, from start: Date, to end: Date, maxResults: Int, token: String) async -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let encodedId = calendar.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendar.id
        guard var components = URLComponents(string: "\(baseURL)/calendars/\(encodedId)/events") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(GoogleEventsResponse.self, from: data) else {
            return []
        }
        return (decoded.items ?? []).compactMap {
            $0.toCalendarEvent(
                calendarName: calendar.summary,
                colorHex: calendar.backgroundColor ?? "#4285F4",
                calendarId: calendar.id
            )
        }
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

    private func fetchCalendarList(token: String) async throws(DozyError) -> [GoogleCalendarItem] {
        if let cached = withCacheLock({ calendarListCache }),
           Date().timeIntervalSince(cached.fetchedAt) < calendarListTTL {
            return cached.items
        }
        guard let url = URL(string: "\(baseURL)/users/me/calendarList") else {
            throw .googleCalendarFetchFailed
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(GoogleCalendarListResponse.self, from: data) else {
            throw .googleCalendarFetchFailed
        }
        let items = decoded.items ?? []
        withCacheLock { calendarListCache = (items: items, fetchedAt: Date()) }
        return items
    }
}

// MARK: - CalendarWriteServiceProtocol
extension GoogleCalendarService: CalendarWriteServiceProtocol {

    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) async throws(DozyError) {
        guard signInService.isSignedIn, let calendarId = event.calendarId else { throw .dataNotFound }
        let token = try await signInService.getValidAccessToken()
        try await patchEvent(event: event, edit: edit, calendarId: calendarId, token: token)
        invalidateCache(for: event.startDate)
    }

    func deleteEvent(_ event: CalendarEvent) async throws(DozyError) {
        guard signInService.isSignedIn, let calendarId = event.calendarId else { throw .dataNotFound }
        let token = try await signInService.getValidAccessToken()
        try await deleteEventRequest(eventId: event.id, calendarId: calendarId, token: token)
        invalidateCache(for: event.startDate)
    }

    private func patchEvent(event: CalendarEvent, edit: CalendarEventEditRequest,
                            calendarId: String, token: String) async throws(DozyError) {
        let encCal = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let encEvt = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.id
        guard let url = URL(string: "\(baseURL)/calendars/\(encCal)/events/\(encEvt)") else {
            throw .googleCalendarFetchFailed
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

        guard let (_, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw .googleCalendarFetchFailed
        }
    }

    private func deleteEventRequest(eventId: String, calendarId: String, token: String) async throws(DozyError) {
        let encCal = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let encEvt = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        guard let url = URL(string: "\(baseURL)/calendars/\(encCal)/events/\(encEvt)") else {
            throw .googleCalendarFetchFailed
        }

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (_, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else {
            throw .googleCalendarFetchFailed
        }
        guard http.statusCode == 204 else {
            throw .googleCalendarWriteFailed(statusCode: http.statusCode)
        }
    }
}
