//
//  EventParsingServiceProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/22/26.
//

import Foundation

protocol EventParsingServiceProtocol {
    /// 자연어 한 줄을 일정 초안으로. 날짜를 전혀 찾지 못하면 throw (DozyError.eventParsingFailed)
    /// - Parameter referenceDate: "내일", "다음주 월요일" 같은 상대 표현의 기준
    func parseEvent(from text: String, referenceDate: Date) async throws -> EventDraft
}
