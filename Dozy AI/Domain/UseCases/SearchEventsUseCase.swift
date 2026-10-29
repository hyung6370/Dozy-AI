//
//  SearchEventsUseCase.swift
//  Dozy AI
//
//  기간이 있는 검색 질의 실행 (#72): 기간 조회 → 조건 필터 → 집계.
//  기간 조회(Composite)가 Apple · Google · Dozy 병합, Dozy 반복 occurrence 전개, 미러 중복 제거를 이미 하므로
//  일정은 한 번만 가져오고, 완료율을 위해 Dozy 원본(isCompleted)과 EventCompletion 을 함께 읽는다.
//

import Foundation
import Combine

struct SearchPeriodResult: Equatable {
    /// 조건에 맞는 일정, 최신순
    var events: [CalendarEvent]
    /// 집계를 물은 경우만
    var aggregate: SearchAggregate?
}

final class SearchEventsUseCase {

    private let fetchEvents: FetchCalendarEventsForPeriodUseCase
    private let fetchDozyEvents: FetchDozyEventsForPeriodUseCase
    private let fetchCompletions: FetchEventCompletionsForPeriodUseCase

    init(
        fetchEvents: FetchCalendarEventsForPeriodUseCase,
        fetchDozyEvents: FetchDozyEventsForPeriodUseCase,
        fetchCompletions: FetchEventCompletionsForPeriodUseCase
    ) {
        self.fetchEvents = fetchEvents
        self.fetchDozyEvents = fetchDozyEvents
        self.fetchCompletions = fetchCompletions
    }

    /// 기간이 없는 intent 는 키워드 검색 대상이라 빈 결과.
    func execute(_ intent: SearchQueryIntent) -> AnyPublisher<SearchPeriodResult, DozyError> {
        guard let period = intent.period else {
            return Just(SearchPeriodResult(events: [], aggregate: nil))
                .setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        return Publishers.Zip3(
            fetchEvents.execute(from: period.start, to: period.end),
            fetchDozyEvents.execute(from: period.start, to: period.end),
            fetchCompletions.execute(from: period.start, to: period.end)
        )
        .map { events, dozyEvents, completions in
            let matched = SearchAggregator.filter(events, intent: intent)
            guard intent.aggregation != .none else {
                return SearchPeriodResult(events: matched, aggregate: nil)
            }
            let lookup = CompletionLookup(
                nonRecurringDozy: Dictionary(
                    dozyEvents
                        .filter { $0.recurrenceRule == "none" || $0.recurrenceRule.isEmpty }
                        .map { ($0.id, $0.isCompleted) },
                    uniquingKeysWith: { first, _ in first }
                ),
                completedKeys: Set(completions.filter(\.isCompleted).map {
                    CompletionLookup.key(eventID: $0.eventID, day: $0.eventDate)
                })
            )
            let aggregate = SearchAggregator.aggregate(
                matched, aggregation: intent.aggregation, period: period, completion: lookup
            )
            return SearchPeriodResult(events: matched, aggregate: aggregate)
        }
        .eraseToAnyPublisher()
    }
}
