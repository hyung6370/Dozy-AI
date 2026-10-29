//
//  NaturalLanguageQueryParser.swift
//  Dozy AI
//
//  [Data Layer] 검색 질의 해석 (#72). NaturalLanguageEventParser 와 같은 구조 — 온디바이스 모델 → 규칙 폴백.
//  - 규칙 해석(QueryRuleParser)은 항상 먼저 돌린다. 모델이 실패하거나 없으면 그대로 결과가 된다.
//  - 한 단어 검색("회의")은 모델을 부르지 않는다 — 기존 키워드 검색이 답이고 모델 지연만 생긴다.
//  - 모델 결과는 QueryRuleParser.merge 가 검증한다 (사전 기간 우선, 지어낸 키워드 · 없는 카테고리 버림).
//

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

final class NaturalLanguageQueryParser: QueryParsingServiceProtocol {

    func parseQuery(from text: String, referenceDate: Date, categories: [String]) async -> SearchQueryIntent {
        let rules = QueryRuleParser.parse(text, referenceDate: referenceDate, categories: categories)
        guard QueryRuleParser.isMultiWord(text) else { return rules }

#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let engine = FoundationModelsEngine()
            if engine.status == .onDevice {
                do {
                    let response = try await engine.queryIntent(from: text, referenceDate: referenceDate, categories: categories)
                    let intent = QueryRuleParser.merge(
                        model: Self.interpretation(from: response), rules: rules,
                        text: text, referenceDate: referenceDate, categories: categories
                    )
                    Logger.search.info("[질의 해석] 온디바이스: kind=\(intent.kind.rawValue, privacy: .public) aggregation=\(intent.aggregation.rawValue, privacy: .public)")
                    return intent
                } catch {
                    Logger.search.error("[질의 해석] 온디바이스 모델 실패 → 규칙: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
#endif
        Logger.search.info("[질의 해석] 규칙: kind=\(rules.kind.rawValue, privacy: .public)")
        return rules
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func interpretation(from response: QueryIntentResponse) -> ModelQueryInterpretation {
        let aggregation: SearchQueryIntent.Aggregation
        switch response.aggregation {
        case .none: aggregation = .none
        case .count: aggregation = .count
        case .totalHours: aggregation = .totalHours
        case .completionRate: aggregation = .completionRate
        }
        return ModelQueryInterpretation(
            startDate: response.startDate,
            endDate: response.endDate,
            keyword: response.keyword,
            category: response.category,
            aggregation: aggregation
        )
    }
#endif
}
