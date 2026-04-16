//
//  FetchDozyEventsUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

// [UseCase] 날짜별 Dozy 이벤트 조회 (편집/삭제용 원본 모델)

final class FetchDozyEventsUseCase {
    
    private let repository: DozyEventRepositoryProtocol
    
    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(for date: Date) -> AnyPublisher<[DozyEvent], DozyError> {
        Publishers.Zip(
            repository.fetchEvents(from: date.startOfDay, to: date.startOfNextDay),
            repository.fetchAllRecurring()
        )
        .map { regular, recurring in
            // 비반복 일정만 date range로 처리 (반복 일정은 occursOn으로 전개)
            let regularOnly = regular.filter { $0.recurrenceRule == "none" || $0.recurrenceRule.isEmpty }
            let recurringToday = recurring.filter { $0.occursOn(date) }
            return (regularOnly + recurringToday).sorted { $0.startDate < $1.startDate }
        }
        .eraseToAnyPublisher()
    }
}
