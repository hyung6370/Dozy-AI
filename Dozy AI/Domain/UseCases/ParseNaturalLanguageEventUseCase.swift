//
//  ParseNaturalLanguageEventUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/22/26.
//

// [UseCase] 입력 정리 -> 파싱 서비스 -> 결과 보정 (종료 >= 시작, 빈 제목 방지)

import Foundation

final class ParseNaturalLanguageEventUseCase {
    
    private let service: EventParsingServiceProtocol
    private let defaultDuration: TimeInterval = 60 * 60
    
    init(service: EventParsingServiceProtocol) {
        self.service = service
    }
    
    func execute(text: String, referenceDate: Date = Date()) async throws -> EventDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DozyError.eventParsingFailed }
        
        var draft = try await service.parseEvent(from: trimmed, referenceDate: referenceDate)
        
        // 보정: 종료가 시작보다 앞이거나 같으면 기본 1시간
        if draft.endDate <= draft.startDate {
            draft.endDate = draft.startDate.addingTimeInterval(defaultDuration)
        }
        // 보정: 제목이 비면 원문을 그대로 제목으로 (사용자가 폼에서 수정)
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = trimmed
        }
        return draft
    }
}
