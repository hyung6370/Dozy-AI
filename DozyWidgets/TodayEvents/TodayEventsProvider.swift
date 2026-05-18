//
//  TodayEventsProvider.swift
//  DozyWidgetsExtension
//
//  Created by Hyungjun KIM on 5/14/26.
//

import WidgetKit
import Foundation

struct TodayEventsProvider: TimelineProvider {
    
    // MARK: - Placeholder (위젯 갤러리 / 첫 진입 시 짧게 보이는 뼈대)
    
    func placeholder(in context: Context) -> TodayEventsEntry {
        .placeholder
    }
    
    // MARK: - Snapshot (위젯 갤러리 미리보기 / quick refresh)
    
    func getSnapshot(in context: Context, completion: @escaping (TodayEventsEntry) -> Void) {
        // 갤러리 (system widget picker) 에서는 샘플 데이터를 보여줌.
        if context.isPreview {
            completion(.sampleWithEvents)
            return
        }
        // 실제 표시 직전엔 진짜 데이터를 한 번 빠르게 fetch.
        Task {
            let entry = await TodayEventsDataSource.shared.entry(for: Date())
            completion(entry)
        }
    }
    
    // MARK: - Timeline (메인 - 미래 entry들 미리 만들어 주기)
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEventsEntry>) -> Void) {
        Task {
            let now = Date()
            let baseEntry = await TodayEventsDataSource.shared.entry(for: now)

            // entries: 시간순으로 "표시 갱신 시점" 마다 entry 1개.
            // - 현재 시각의 entry
            // - 각 일정의 시작 시각 (focus item 이 바뀌므로 갱신 필요)
            // - 각 일정의 종료 시각 (완료된 일정이 reschedule 되거나 카운터 변경)
            // - 자정 (오늘이 끝나고 내일 일정 보여줘야 함)
            var transitionDates: Set<Date> = [now]
            for ev in baseEntry.events {
                if ev.start > now { transitionDates.insert(ev.start) }
                if ev.end > now { transitionDates.insert(ev.end) }
            }
            if let endOfToday = Calendar.current.date(
                bySettingHour: 23, minute: 59, second: 59, of: now
            ) {
                transitionDates.insert(endOfToday)
            }
            
            // OS 가 budget 으로 보통 ~12 entries 까지 받아주므로 10개로 cap.
            let sorted = Array(transitionDates).sorted().prefix(10)
            
            var entries: [TodayEventsEntry] = []
            for d in sorted {
                let entry = await TodayEventsDataSource.shared.entry(for: d)
                entries.append(entry)
            }
            
            // .atEnd 정책 — timeline 의 마지막 entry 시각 도래 시 자동으로 새 timeline 요청.
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}
