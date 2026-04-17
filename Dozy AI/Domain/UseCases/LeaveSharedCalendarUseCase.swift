//
//  LeaveSharedCalendarUseCase.swift
//  Dozy AI
//

import Foundation
import Combine

final class LeaveSharedCalendarUseCase {
    private let service: SharedCalendarServiceProtocol

    init(service: SharedCalendarServiceProtocol) {
        self.service = service
    }

    /// 일반 멤버 → leave, owner → delete (CASCADE로 파트너도 제거)
    func execute(calendarID: String, isOwner: Bool) -> AnyPublisher<Void, DozyError> {
        if isOwner {
            return service.delete(calendarID: calendarID)
        } else {
            return service.leave(calendarID: calendarID)
        }
    }
}
