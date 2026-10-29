//
//  ParseSearchQueryUseCase.swift
//  Dozy AI
//
//  검색 질의 해석 + 애널리틱스 `search_query(kind, engine)` (#72).
//  ViewModel 이 디바운스 · return 키로 확정된 질의만 넘기므로 질의 1건당 1회 기록된다.
//

import Foundation

final class ParseSearchQueryUseCase {

    private let parser: QueryParsingServiceProtocol
    private let analytics: AnalyticsServiceProtocol

    init(parser: QueryParsingServiceProtocol, analytics: AnalyticsServiceProtocol = NoopAnalyticsService()) {
        self.parser = parser
        self.analytics = analytics
    }

    func execute(text: String, referenceDate: Date = Date(), categories: [String]) async -> SearchQueryIntent {
        let intent = await parser.parseQuery(from: text, referenceDate: referenceDate, categories: categories)
        analytics.track(.searchQuery(kind: intent.kind, engine: intent.source))
        return intent
    }
}
