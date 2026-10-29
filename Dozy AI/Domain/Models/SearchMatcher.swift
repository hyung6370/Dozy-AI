//
//  SearchMatcher.swift
//  Dozy AI
//
//  검색 화면 키워드 매칭 (#72 선행 리팩터링). SearchView 에 있던 필터 · 중복 제거 · 날짜 그룹을 순수 계산으로 옮겼다.
//  동작은 리팩터링 전과 같다 — 대소문자 무시 `contains`, 앞뒤 공백 제거, 한 글자부터 검색.
//  #72 의 자연어 질의는 기간 · 집계를 이 결과 위에 얹는다 (해석 실패 시 이 키워드 결과가 그대로 폴백).
//

import Foundation

struct SearchResults {
    var categories: [UserCategory] = []
    var workLogs: [WorkLog] = []
    /// Dozy · Apple · Google 통합, 최신순
    var events: [CalendarEvent] = []

    var isEmpty: Bool { categories.isEmpty && workLogs.isEmpty && events.isEmpty }

    /// 날짜(하루 시작)별 묶음, 최신 날짜 먼저. 같은 날 안의 순서는 `events` 순서를 따른다.
    var eventsByDate: [(date: Date, events: [CalendarEvent])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }
}

enum SearchMatcher {

    /// 검색어 정규화 — 앞뒤 공백 제거 + 소문자
    static func normalize(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// - Parameters:
    ///   - query: 정규화 전 입력. 비어 있으면 빈 결과.
    ///   - externalEvents: Apple · Google 일정. `.dozy` 는 `dozyEvents` 로 따로 받으므로 호출부에서 뺀다.
    static func match(
        query: String,
        dozyEvents: [DozyEvent],
        externalEvents: [CalendarEvent],
        workLogs: [WorkLog],
        categories: [UserCategory]
    ) -> SearchResults {
        let q = normalize(query)
        guard !q.isEmpty else { return SearchResults() }

        let matchedCategories = categories.filter { $0.name.lowercased().contains(q) }

        let matchedLogs = workLogs
            .filter { log in
                log.aiSummary.lowercased().contains(q)
                    || log.highlights.contains(where: { $0.lowercased().contains(q) })
                    || log.nextActions.contains(where: { $0.lowercased().contains(q) })
                    || log.memos.contains(where: { $0.lowercased().contains(q) })
            }
            .sorted(by: { $0.date > $1.date })

        let dozy: [CalendarEvent] = dozyEvents
            .filter { e in
                e.title.lowercased().contains(q)
                    || (e.location ?? "").lowercased().contains(q)
                    || (e.notes ?? "").lowercased().contains(q)
                    || e.memos.contains(where: { $0.lowercased().contains(q) })
                    || e.category.lowercased().contains(q)
            }
            .map { $0.toCalendarEvent() }

        let external = externalEvents.filter { e in
            e.title.lowercased().contains(q)
                || (e.location ?? "").lowercased().contains(q)
                || (e.notes ?? "").lowercased().contains(q)
        }

        // Dozy 가 Apple/Google 쪽에 중복으로 들어올 수 있으므로 id 로 중복 제거하되,
        // 반복 이벤트의 여러 occurrence(동일 eventIdentifier, 상이한 startDate)는 보존하기 위해
        // id + startDate 조합을 키로 사용.
        var seen = Set<String>()
        let combined = (dozy + external).filter {
            seen.insert("\($0.id)_\($0.startDate.timeIntervalSince1970)").inserted
        }

        return SearchResults(
            categories: matchedCategories,
            workLogs: matchedLogs,
            events: combined.sorted(by: { $0.startDate > $1.startDate })
        )
    }

    /// 결과 행 아래에 보여 줄 메모 스니펫 — Dozy 메모 우선, 없으면 notes.
    static func matchedMemo(for event: CalendarEvent, dozyEvent: DozyEvent?, query: String) -> String? {
        let q = normalize(query)
        guard !q.isEmpty else { return nil }
        if event.source == .dozy,
           let dozyEvent,
           let memo = dozyEvent.memos.first(where: { $0.lowercased().contains(q) }) {
            return memo
        }
        if let notes = event.notes, notes.lowercased().contains(q) {
            return notes
        }
        return nil
    }

    /// 일지 카드 안에서 검색어가 들어간 메모들
    static func matchedMemos(in log: WorkLog, query: String) -> [String] {
        let q = normalize(query)
        guard !q.isEmpty else { return [] }
        return log.memos.filter { $0.lowercased().contains(q) }
    }
}
