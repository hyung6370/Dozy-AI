//
//  ToggleEventCompletionIntent.swift
//  DozyWidgetsExtension
//
//  위젯에서 일정 row 끝의 체크박스를 탭하면 실행되는 App Intent.
//  공유 App Group SwiftData store 를 열어 일정 종류별로 완료 상태를 토글하고,
//  TodayEventCache 에도 미러링한 뒤 위젯 timeline 을 reload 한다.
//

import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct ToggleEventCompletionIntent: AppIntent {

    static var title: LocalizedStringResource = "일정 완료 토글"
    static var description = IntentDescription("위젯에서 오늘 일정의 완료 상태를 토글합니다.")
    static var isDiscoverable: Bool = false

    /// 위젯이 보여주는 CalendarEvent 의 stable id.
    /// (Dozy 비반복: DozyEvent.id, Apple/Google/반복: source id 또는 occurrence id)
    @Parameter(title: "Event ID")
    var eventID: String

    /// 일정 발생 일자 (EventCompletion 키 구성에 필요). 위젯 entry 의 date 를 그대로 전달.
    @Parameter(title: "Event Date")
    var eventDate: Date

    init() {}

    init(eventID: String, eventDate: Date) {
        self.eventID = eventID
        self.eventDate = eventDate
    }

    func perform() async throws -> some IntentResult {
        await Self.toggle(eventID: eventID, eventDate: eventDate)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    // MARK: - Toggle Logic

    /// 공유 store 를 열고 일정 종류를 판별해 해당 entity 의 완료 상태를 토글.
    /// - Dozy 비반복 일정 (`recurrenceRule == "none"`): `DozyEvent.isCompleted` 직접 토글.
    /// - 그 외 (Apple/Google/반복 Dozy): `EventCompletion` 테이블에 eventID + eventDate 키로 upsert.
    /// - 결과 상태를 `TodayEventCache.isCompleted` 에 미러링 → 다음 위젯 리로드에서 즉시 반영.
    @MainActor
    static func toggle(eventID: String, eventDate: Date) async {
        let appGroupID = "group.com.dozy-ai.shared"
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("default.store") else {
            #if DEBUG
            print("❌ [ToggleIntent] App Group container 접근 실패")
            #endif
            return
        }

        let schema = Schema([
            TodayEventCache.self,
            DozyEvent.self,
            EventCompletion.self,
            UserCategory.self,
        ])
        let config = ModelConfiguration(schema: schema, url: storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            #if DEBUG
            print("❌ [ToggleIntent] ModelContainer 생성 실패")
            #endif
            return
        }

        let context = container.mainContext
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: eventDate)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? eventDate

        var newCompletedState: Bool? = nil

        // ── 1) Dozy 비반복 일정인지 확인 → DozyEvent.isCompleted 토글
        let dozyPred = #Predicate<DozyEvent> { $0.id == eventID }
        let dozyMatch = (try? context.fetch(FetchDescriptor<DozyEvent>(predicate: dozyPred)))?.first

        if let dozyEvent = dozyMatch, dozyEvent.recurrenceRule == "none" {
            dozyEvent.isCompleted.toggle()
            dozyEvent.updatedAt = Date()
            newCompletedState = dozyEvent.isCompleted
        } else {
            // ── 2) Apple/Google 또는 반복 Dozy → EventCompletion upsert
            let pred = #Predicate<EventCompletion> { $0.eventID == eventID }
            let existing = (try? context.fetch(FetchDescriptor<EventCompletion>(predicate: pred)))?
                .first { $0.eventDate >= dayStart && $0.eventDate < dayEnd }
            if let existing {
                existing.isCompleted.toggle()
                existing.updatedAt = Date()
                newCompletedState = existing.isCompleted
            } else {
                let new = EventCompletion(eventID: eventID, eventDate: dayStart)
                new.isCompleted = true
                context.insert(new)
                newCompletedState = true
            }
        }

        // ── 3) TodayEventCache 미러 — 위젯이 다음 reload 에서 새 상태로 즉시 표시
        if let newState = newCompletedState {
            let cachePred = #Predicate<TodayEventCache> { $0.id == eventID }
            if let cache = (try? context.fetch(FetchDescriptor<TodayEventCache>(predicate: cachePred)))?.first {
                cache.isCompleted = newState
            }
        }

        do {
            try context.save()
            #if DEBUG
            print("✅ [ToggleIntent] toggled \(eventID) → \(newCompletedState ?? false)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [ToggleIntent] save 실패: \(error)")
            #endif
        }
    }
}
