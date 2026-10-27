//
//  HolidayService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/27/26.
//

import Foundation
import Combine
import OSLog

final class HolidayService {
    
    // MARK: - JSON 페이로드
    private struct Payload: Decodable {
        let version: String
        let range: RangeInfo
        let holidays: [Entry]
        
        struct RangeInfo: Decodable {
            let from: String
            let to: String
        }
        
        struct Entry: Decodable {
            let date: String // "YYYY-MM-DD"
            let name: String
            let isSubstitute: Bool
        }
    }
    
    // MARK: - State
    
    private var indexByDay: [Date: [Payload.Entry]] = [:]
    private(set) var loadedVersion: String = ""
    private(set) var rangeStart: Date?
    private(set) var rangeEnd: Date?
    
    private let logger = Logger(subsystem: "ai.dozy.app", category: "holidays")
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
    
    init() {
        loadFromCacheOrBundle()
        Task { await refreshFromRemoteIfPossible() }
    }
    
    // MARK: - 조회 API
    
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        let day = Calendar.current.startOfDay(for: date)
        let events = (indexByDay[day] ?? []).map { Self.makeCalendarEvent(from: $0, on: day) }
        return Just(events).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
    
    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let endDay   = cal.startOfDay(for: end)   // exclusive
        var events: [CalendarEvent] = []
        for (day, entries) in indexByDay where day >= startDay && day < endDay {
            for entry in entries {
                events.append(Self.makeCalendarEvent(from: entry, on: day))
            }
        }
        events.sort { $0.startDate < $1.startDate }
        return Just(events).setFailureType(to: DozyError.self).eraseToAnyPublisher()
    }
    
    // MARK: - CalendarEvent 매핑

    private static func makeCalendarEvent(from entry: Payload.Entry, on day: Date) -> CalendarEvent {
        // 같은 날 23:59:59 — endDate 를 다음날 자정으로 설정하면 bar layout engine 이
        // startOfDay(endDate) 를 다음날로 인식해 single-day 공휴일이 2일짜리 막대로 그려짐.
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: day)?
            .addingTimeInterval(-1) ?? day
        return CalendarEvent(
            id: "holiday_\(entry.date)_\(entry.name)",
            calendarId: nil,
            title: entry.name,
            startDate: day,
            endDate: endOfDay,
            location: nil,
            notes: nil,
            isAllDay: true,
            calendarName: "공휴일",
            calendarColorHex: "#E54848",   // 한국 캘린더 관습대로 빨강
            source: .holiday,
            priority: 0,
            isPinned: false,
            category: "공휴일",
            sharedCalendarID: nil,
            ownerID: nil,
            externalSource: nil,
            externalEventID: nil,
            externalDeleted: false
        )
    }
    
    // MARK: - 로딩 (캐시 -> 번들)
    
    /// version 비교는 ISO 날짜 문자열 (`yyyy-MM-dd`)의 lexicographic 비교 = chronological
    private func loadFromCacheOrBundle() {
        let cached = loadCachePayload()
        let bundled = loadBundlePayload()
        
        if let cached, let bundled {
            // 앱 업데이트로 번들이 캐시보다 새 버전을 들고 왔다면 번들 우선.
            if cached.version >= bundled.version {
                apply(cached); logger.info("✅ holidays from cache (v\(cached.version))")
            } else {
                apply(bundled); logger.info("✅ holidays from bundle (newer than cache, v\(bundled.version))")
            }
        } else if let cached {
            apply(cached); logger.info("✅ holidays from cache (v\(cached.version))")
        } else if let bundled {
            apply(bundled); logger.info("✅ holidays from bundle (v\(bundled.version))")
        } else {
            logger.error("⚠️  no holidays.json available — bundle missing?")
        }
    }
    
    private func loadBundlePayload() -> Payload? {
        guard let url = Bundle.main.url(forResource: "holidays", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
    
    private func loadCachePayload() -> Payload? {
        guard let url = try? cacheFileURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
    
    private func apply(_ payload: Payload) {
        var index: [Date: [Payload.Entry]] = [:]
        for entry in payload.holidays {
            guard let day = dateFormatter.date(from: entry.date)
                .map({ Calendar.current.startOfDay(for: $0) }) else { continue }
            index[day, default: []].append(entry)
        }
        self.indexByDay = index
        self.loadedVersion = payload.version
        self.rangeStart = dateFormatter.date(from: payload.range.from)
            .map { Calendar.current.startOfDay(for: $0) }
        self.rangeEnd = dateFormatter.date(from: payload.range.to)
            .map { Calendar.current.startOfDay(for: $0) }
    }
    
    // MARK: - 원격 갱신 (Supabase Storage의 public bucket)
    
    private func refreshFromRemoteIfPossible() async {
        guard let url = remoteURL() else {
            logger.info("⏭ no Supabase host — skip remote refresh")
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                logger.warning("⏭ remote status non-200 — keep existing")
                return
            }
            let remote = try JSONDecoder().decode(Payload.self, from: data)
            // 같거나 더 오래된 버전이면 굳이 갱신 안 함.
            guard remote.version > loadedVersion else {
                logger.info("⏭ remote version (\(remote.version)) ≤ loaded (\(self.loadedVersion)) — skip")
                return
            }
            try writeCache(data)
            await MainActor.run { self.apply(remote) }
            logger.info("✅ holidays refreshed from remote (v\(remote.version), \(remote.holidays.count) 건)")
        } catch {
            logger.warning("⚠️  remote fetch failed: \(error.localizedDescription) — keep cache/bundle")
        }
    }
    
    /// Supabase Storage 의 public 객체 URL.
    /// 버킷 이름: `dozy`, 파일: `holidays.json` (Phase 외 작업: 사용자가 Supabase 대시보드에서 만들어야 함).
    private func remoteURL() -> URL? {
        let info = Bundle.main.infoDictionary ?? [:]
#if DEBUG
        let hostKey = AppEnvironment.current == .production ? "PROD_SUPABASE_HOST" : "SUPABASE_HOST"
#else
        let hostKey = "SUPABASE_HOST"
#endif
        guard let host = info[hostKey] as? String, !host.isEmpty else { return nil }
        return URL(string: "https://\(host)/storage/v1/object/public/dozy/holidays.json")
    }
    
    // MARK: - 캐시 파일 경로
    
    private func cacheFileURL() throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                             appropriateFor: nil, create: true)
            .appendingPathComponent("Holidays", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("holidays.json")
    }
    
    private func writeCache(_ data: Data) throws {
        let url = try cacheFileURL()
        try data.write(to: url, options: .atomic)
    }
}
