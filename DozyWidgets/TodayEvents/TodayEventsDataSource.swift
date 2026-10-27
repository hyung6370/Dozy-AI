//
//  TodayEventsDataSource.swift
//  DozyWidgetsExtension
//
//  Created by Hyungjun KIM on 5/14/26.
//

import Foundation
import SwiftData

actor TodayEventsDataSource {
    
    static let shared = TodayEventsDataSource()
    
    private let appGroupID = "group.com.dozy-ai.shared"
    
    /// 위젯 전용 read-only model container. 메인 앱과 동일 store 를 가리킴.
    /// 위젯이 쓰는 경우는 없으므로 read-only 로 충분.
    private lazy var container: ModelContainer? = {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("default.store")
        else { return nil }

        // 위젯이 필요한 entity 만 schema 에 등록 — 메모리 budget 절약.
        // TodayEventCache 가 핵심 — 메인 앱이 머지된 (Apple/Google/Dozy/Holiday) 오늘 일정을
        // 여기에 mirror 한다. DozyEvent / UserCategory 는 향후 다른 위젯이 직접 fetch 할 때 위해 둠.
        let schema = Schema([
            TodayEventCache.self,
            DozyEvent.self,
            EventCompletion.self,
            UserCategory.self,
        ])
        // ⚠️ allowsSave: false 를 명시하면 SwiftData 의 schema auto-migration 이 막혀
        // ("attempt to write a readonly database") store open 실패. 위젯 코드는 명시적으로
        // save() 를 호출하지 않으므로 기본값(쓰기 허용)으로도 실질 read-only.
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try? ModelContainer(for: schema, configurations: [config])
    }()
    
    /// 주어진 시각 기준 "오늘 일정" + "이번 달 일정 있는 날짜들" 을 읽어 entry 로 변환.
    func entry(for date: Date) async -> TodayEventsEntry {
        guard let container else {
            return TodayEventsEntry(
                date: date,
                events: [],
                completedCount: 0,
                totalCount: 0,
                errorMessage: "데이터 접근 실패",
                monthEventDates: []
            )
        }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let context = ModelContext(container)

        // ── 1) 오늘 일정 fetch — TodayEventCache (메인 앱이 머지해서 mirror 한 데이터) ──
        // 이전엔 DozyEvent 만 봤지만, 그건 사용자가 앱에서 직접 만든 일정만 포함되어 Apple/Google
        // 캘린더 일정이 위젯에 안 나오는 한계가 있었음. 이제 TodayEventCache 가 모든 source 머지본.
        let todayPredicate = #Predicate<TodayEventCache> { event in
            event.startDate < endOfDay && event.endDate >= startOfDay
        }
        let todayDescriptor = FetchDescriptor<TodayEventCache>(
            predicate: todayPredicate,
            sortBy: [SortDescriptor(\.startDate)]
        )
        let cached = (try? context.fetch(todayDescriptor)) ?? []
        #if DEBUG
        let storePath = container.configurations.first?.url.path ?? "?"
        print("🔎 [Widget] fetched \(cached.count) events from store: \(storePath)")
        #endif

        let snapshots: [WidgetEventSnapshot] = cached.map { ev in
            WidgetEventSnapshot(
                id: ev.id,
                title: ev.title,
                start: ev.startDate,
                end: ev.endDate,
                isAllDay: ev.isAllDay,
                colorHex: ev.colorHex,
                isCompleted: ev.isCompleted,
                isPinned: ev.isPinned
            )
        }

        // ── 2) 이번 달 일정 있는 날짜 — 메인 앱이 App Group UserDefaults 에 캐싱한 dates Set.
        // HomeViewModel.refreshMonthEventDatesForWidget() 에서 fetch 후 저장.
        // 메인 앱을 한 번도 안 켰거나 다른 달 데이터가 stale 한 경우 빈 Set.
        let allMonthDates = TodayEventCacheWriter.loadMonthEventDates()
        // 이번 달 범위만 필터 — 캐시가 이전 달 데이터를 들고 있어도 grid 표시는 정확.
        let monthInterval = cal.dateInterval(of: .month, for: date)
        let monthStart = monthInterval?.start ?? startOfDay
        let monthEnd = monthInterval?.end ?? endOfDay
        let monthEventDates = allMonthDates.filter { $0 >= monthStart && $0 < monthEnd }

        let totalCount = snapshots.count
        let completedCount = snapshots.filter { $0.isCompleted }.count

        return TodayEventsEntry(
            date: date,
            events: snapshots,
            completedCount: completedCount,
            totalCount: totalCount,
            errorMessage: nil,
            monthEventDates: monthEventDates
        )
    }
}
