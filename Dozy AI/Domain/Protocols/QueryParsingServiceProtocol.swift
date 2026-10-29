//
//  QueryParsingServiceProtocol.swift
//  Dozy AI
//
//  검색 질의 해석 (#72). 구현은 Data 의 NaturalLanguageQueryParser (온디바이스 모델 → 규칙 폴백).
//  실패하지 않는다 — 해석할 게 없으면 키워드만 있는 intent 를 돌려줘 기존 키워드 검색으로 떨어진다.
//

import Foundation

protocol QueryParsingServiceProtocol {
    func parseQuery(from text: String, referenceDate: Date, categories: [String]) async -> SearchQueryIntent
}
