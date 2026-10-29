//
//  SearchAggregator.swift
//  Dozy AI
//
//  자연어 질의 집계 (#72). "AI 는 해석만, 숫자는 Swift 가" — 모델은 기간 · 키워드 · 집계 종류만 내고 수치는 여기서 센다.
//  - 공휴일은 일정이 아니므로 뺀다
//  - 반복 일정은 occurrence 하나를 한 번으로 센다 (기간 조회가 이미 occurrence 로 펼쳐 준다)
//  - 시간 합산은 종일 일정을 빼고, 기간 경계 밖은 잘라낸다. 겹치는 일정은 단순 합산 (#72 결정)
//

import Foundation

struct SearchAggregate: Equatable {
    var aggregation: SearchQueryIntent.Aggregation
    /// 기간 · 조건에 맞는 일정 수 (종일 포함)
    var eventCount: Int
    /// 종일 제외 시간 합 (분)
    var totalMinutes: Int
    /// 시간 합산에서 뺀 종일 일정 수
    var allDayCount: Int
    var completedCount: Int

    /// 0...1, 일정이 없으면 nil
    var completionRate: Double? {
        eventCount == 0 ? nil : Double(completedCount) / Double(eventCount)
    }
}

/// 완료 판정 — ToggleEventCompletionUseCase 와 같은 기준.
/// Dozy 비반복 일정은 DozyEvent.isCompleted, 그 외(Apple · Google · 반복 Dozy)는 EventCompletion(eventID, 같은 날).
struct CompletionLookup: Equatable {
    /// 비반복 Dozy 일정 id → 완료 여부
    var nonRecurringDozy: [String: Bool] = [:]
    /// 완료된 EventCompletion 의 `key(eventID:day:)`
    var completedKeys: Set<String> = []

    static func key(eventID: String, day: Date, calendar: Calendar = .current) -> String {
        "\(eventID)_\(Int(calendar.startOfDay(for: day).timeIntervalSince1970))"
    }

    func isCompleted(_ event: CalendarEvent, calendar: Calendar = .current) -> Bool {
        if event.source == .dozy, let done = nonRecurringDozy[event.id] { return done }
        return completedKeys.contains(Self.key(eventID: event.id, day: event.startDate, calendar: calendar))
    }
}

enum SearchAggregator {

    /// 기간 조회 결과에서 질의 조건에 맞는 일정만, 최신순.
    static func filter(_ events: [CalendarEvent], intent: SearchQueryIntent) -> [CalendarEvent] {
        let tokens = intent.keywordTokens
        let hint = intent.categoryHint
        return events
            .filter { $0.source != .holiday }
            .filter { event in
                if let period = intent.period, !(event.startDate < period.end && event.endDate >= period.start) {
                    return false
                }
                if tokens.isEmpty {
                    return hint.map { event.category == $0 } ?? true
                }
                let haystack = [event.title, event.location ?? "", event.notes ?? ""]
                    .joined(separator: "\n").lowercased()
                return tokens.allSatisfy { token in
                    haystack.contains(token)
                        || (hint.map { $0.lowercased() == token && event.category == $0 } ?? false)
                }
            }
            .sorted { $0.startDate > $1.startDate }
    }

    static func aggregate(
        _ events: [CalendarEvent],
        aggregation: SearchQueryIntent.Aggregation,
        period: SearchQueryIntent.Period,
        completion: CompletionLookup,
        calendar: Calendar = .current
    ) -> SearchAggregate {
        var minutes = 0
        var allDay = 0
        var completed = 0
        for event in events {
            if event.isAllDay {
                allDay += 1
            } else {
                let start = max(event.startDate, period.start)
                let end = min(event.endDate, period.end)
                if end > start { minutes += Int(end.timeIntervalSince(start) / 60) }
            }
            if completion.isCompleted(event, calendar: calendar) { completed += 1 }
        }
        return SearchAggregate(
            aggregation: aggregation,
            eventCount: events.count,
            totalMinutes: minutes,
            allDayCount: allDay,
            completedCount: completed
        )
    }
}
