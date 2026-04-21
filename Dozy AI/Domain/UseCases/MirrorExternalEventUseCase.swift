//
//  MirrorExternalEventUseCase.swift
//  Dozy AI
//
//  Apple/Google 원본 이벤트를 Dozy 공유 캘린더로 미러링하는 유스케이스.
//

import Foundation
import Combine

final class MirrorExternalEventUseCase {

    private let repository: DozyEventRepositoryProtocol

    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }

    func execute(
        _ origin: CalendarEvent,
        to sharedCalendarID: String
    ) -> AnyPublisher<DozyEvent, DozyError> {
        repository.mirrorExternalEvent(origin, to: sharedCalendarID)
    }
}
