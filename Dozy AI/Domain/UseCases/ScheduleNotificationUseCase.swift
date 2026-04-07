//
//  ScheduleNotificationUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation

final class ScheduleNotificationUseCase {

    private let service: NotificationServiceProtocol
    private let notificationRepository: NotificationRepository

    init(service: NotificationServiceProtocol, notificationRepository: NotificationRepository) {
        self.service = service
        self.notificationRepository = notificationRepository
    }

    func execute(for event: DozyEvent) {
        guard event.notificationMinutesBefore >= 0 else { return }

        let triggerDate = Calendar.current.date(
            byAdding: .minute,
            value: -event.notificationMinutesBefore,
            to: event.startDate
        ) ?? event.startDate

        let body: String
        switch event.notificationMinutesBefore {
        case 0:    body = "\(event.title) 일정이 곧 시작됩니다."
        case 60:   body = "\(event.title) 일정이 1시간 후 시작됩니다."
        default:   body = "\(event.title) 일정이 \(event.notificationMinutesBefore)분 후 시작됩니다."
        }

        // 미래 알림만 시스템에 예약 (과거는 불가)
        if triggerDate > Date() {
            service.schedule(identifier: event.id, title: "곧 있을 일정", body: body, triggerDate: triggerDate)
        }

        // 기록은 항상 저장 (과거 포함)
        let record = NotificationRecord(
            eventID: event.id,
            eventTitle: event.title,
            body: body,
            deliveryDate: triggerDate
        )
        notificationRepository.save(record)
    }
}
