//
//  TodayEventCacheWriter.swift
//  Dozy AI
//
//  HomeViewModel 이 머지된 [CalendarEvent] 를 위젯용 SwiftData 캐시로 upsert 할 때 쓰는 helper.
//  모든 source (Apple / Google / Dozy / Holiday) 의 일정을 같은 SwiftData store 로 미러링
//  → 위젯이 한 곳에서 모두 읽도록 한다.
//

import Foundation
import SwiftData

enum TodayEventCacheWriter {

    /// 위젯과 메인 앱이 공유하는 App Group identifier.
    private static let appGroupID = "group.com.dozy-ai.shared"

    /// "이번 달에 일정이 있는 날짜들" 을 보관할 파일명.
    /// UserDefaults 의 App Group suite 는 sandbox simulator 에서 CFPreferences 가 거부하는
    /// 경우가 있어 (`kCFPreferencesAnyUser with a container ...`) 더 안전한 파일 기반으로 전환.
    private static let monthEventDatesFilename = "widget.monthEventDates.v1.json"

    /// App Group container 안의 month dates 파일 URL. 접근 불가면 nil.
    private static var monthEventDatesURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(monthEventDatesFilename)
    }

    /// Dozy 일정 1건만 캐시에 즉시 upsert (오늘 일정이면 insert/replace, 아니면 무시).
    /// `loadTodayData()` 의 풀 fetch 체인을 기다리지 않고 위젯에 빠른 시각 피드백을
    /// 주기 위함. 호출 후 `WidgetCenter.reloadAllTimelines()` 을 곧장 부르면 됨.
    @MainActor
    static func upsertSingleDozyEvent(_ event: DozyEvent, container: ModelContainer) {
        let context = container.mainContext
        let id = event.id

        // 같은 id 의 기존 row 삭제 (replace 효과).
        let existingPredicate = #Predicate<TodayEventCache> { $0.id == id }
        let existing = (try? context.fetch(FetchDescriptor<TodayEventCache>(predicate: existingPredicate))) ?? []
        for entity in existing { context.delete(entity) }

        // 오늘 범위에 속하는 경우만 insert.
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        guard let endOfToday = cal.date(byAdding: .day, value: 1, to: startOfToday) else { return }

        if event.startDate < endOfToday && event.endDate >= startOfToday {
            context.insert(TodayEventCache(
                id: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                colorHex: event.colorHex,
                isCompleted: event.isCompleted,
                isPinned: event.isPinned,
                cachedAt: Date()
            ))
        }
        try? context.save()
    }

    /// 캐시에서 특정 id 의 row 제거 — 이벤트 삭제 후 즉시 호출.
    @MainActor
    static func removeSingleEvent(id: String, container: ModelContainer) {
        let context = container.mainContext
        let predicate = #Predicate<TodayEventCache> { $0.id == id }
        let existing = (try? context.fetch(FetchDescriptor<TodayEventCache>(predicate: predicate))) ?? []
        for entity in existing { context.delete(entity) }
        try? context.save()
    }

    /// 메인 앱이 이번 달 머지된 일정을 받았을 때 호출 — 일정 있는 startOfDay 들의 Set 을
    /// App Group container 의 JSON 파일로 저장. 위젯이 다음 timeline 에서 읽음.
    static func updateMonthEventDates(_ events: [CalendarEvent]) {
        guard let url = monthEventDatesURL else {
            #if DEBUG
            print("❌ [Widget Cache] monthEventDates — App Group container 접근 실패")
            #endif
            return
        }
        let cal = Calendar.current
        let timestamps = Array(Set(events.map { cal.startOfDay(for: $0.startDate).timeIntervalSince1970 }))
        do {
            let data = try JSONEncoder().encode(timestamps)
            try data.write(to: url, options: .atomic)
            #if DEBUG
            print("📦 [Widget Cache] monthEventDates 저장: \(timestamps.count) days → \(url.path)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Widget Cache] monthEventDates 저장 실패: \(error)")
            #endif
        }
    }

    /// 위젯 쪽에서 호출 — 저장된 month dates 를 Set<Date> 으로 복원.
    static func loadMonthEventDates() -> Set<Date> {
        guard let url = monthEventDatesURL,
              let data = try? Data(contentsOf: url),
              let timestamps = try? JSONDecoder().decode([TimeInterval].self, from: data) else {
            #if DEBUG
            print("🔎 [Widget] monthEventDates 파일 없음 또는 read 실패")
            #endif
            return []
        }
        let dates = Set(timestamps.map { Date(timeIntervalSince1970: $0) })
        #if DEBUG
        print("🔎 [Widget] monthEventDates loaded: \(dates.count) days")
        #endif
        return dates
    }


    /// 오늘 머지된 일정 list 를 캐시 entity 로 replace.
    ///
    /// 전략: "wipe + insert all" — 적은 row 수 (~수십 개) 라 단순한 게 안전. partial diff
    /// 는 race condition + 복잡도만 늘림.
    ///
    /// - Parameters:
    ///   - events: 메인 앱이 표시할 오늘 일정. 이미 머지·정렬된 상태.
    ///   - completions: eventID → isCompleted 매핑. (Apple/Google 은 EventCompletion 테이블,
    ///                  Dozy 비반복은 DozyEvent.isCompleted)
    ///   - displaySettings: eventID → priority/isPinned. Apple/Google 일정의 사용자 설정.
    ///   - dozyEventsByID: Dozy 비반복 일정의 직접 isPinned 조회용.
    ///   - container: shared App Group container.
    @MainActor
    static func upsert(
        events: [CalendarEvent],
        completions: [String: Bool],
        dozyEventsByID: [String: DozyEvent],
        container: ModelContainer
    ) {
        let context = container.mainContext

        // ① wipe 기존 항목.
        let existing = (try? context.fetch(FetchDescriptor<TodayEventCache>())) ?? []
        for entity in existing { context.delete(entity) }

        // ② 새 events 삽입.
        let now = Date()
        for event in events {
            let isCompleted = completions[event.id] ?? false
            // isPinned 는 CalendarEvent.isPinned 가 이미 EventDisplaySettings + DozyEvent 머지된 값.
            let cache = TodayEventCache(
                id: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                colorHex: event.calendarColorHex,
                isCompleted: isCompleted,
                isPinned: event.isPinned,
                cachedAt: now
            )
            context.insert(cache)
        }

        // ③ save — 위젯이 다음 read 에서 새 데이터를 볼 수 있도록 명시적 commit.
        do {
            try context.save()
            #if DEBUG
            print("📦 [Widget Cache] upsert OK — \(events.count) events (deleted \(existing.count) old). store: \(container.configurations.first?.url.path ?? "?")")
            #endif
        } catch {
            // 캐시 갱신 실패는 앱 동작에 치명적이지 않음 — 위젯이 stale 데이터를 보일 뿐.
            // 다음 loadTodayData 에서 재시도.
            #if DEBUG
            print("❌ [Widget Cache] save failed: \(error)")
            #endif
            assertionFailure("TodayEventCache save failed: \(error)")
        }
    }
}
