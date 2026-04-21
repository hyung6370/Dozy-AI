//
//  DozyEventRepositoryProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

protocol DozyEventRepositoryProtocol {
    func fetchEvents(from: Date, to: Date) -> AnyPublisher<[DozyEvent], DozyError>
    func fetchAllRecurring() -> AnyPublisher<[DozyEvent], DozyError>
    func save(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>
    func update(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>
    func delete(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>

    /// Apple/Google 원본 이벤트를 Dozy 공유 캘린더로 미러링.
    /// 같은 (현재 사용자, externalSource, externalEventID) 조합이 이미 있으면 대상 공유 캘린더만 갱신한다.
    func mirrorExternalEvent(
        _ origin: CalendarEvent,
        to sharedCalendarID: String
    ) -> AnyPublisher<DozyEvent, DozyError>
}
