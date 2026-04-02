//
//  ScheduleNotificationUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation

final class ScheduleNotificationUseCase {
    
    private let service: NotificationServiceProtocol
    
    init(service: NotificationServiceProtocol) {
        self.service = service
    }
    
    func execute(for event: DozyEvent) {
        guard event.notificationMinutesBefore >= 0 else { return }
        
        let triggerDate = Calendar.current.date(
            byAdding: .minute,
            value: -event.notificationMinutesBefore,
            to: event.startDate
        ) ?? event.startDate
        
        guard triggerDate > Date() else { return }
        
        let body: String
        switch event.notificationMinutesBefore {
        case 0:    body = "\(event.title) 일정이 곧 시작됩니다."
        case 60:   body = "\(event.title) 일정이 1시간 후 시작됩니다."
        default:   body = "\(event.title) 일정이 \(event.notificationMinutesBefore)분 후 시작됩니다."
        }
        service.schedule(identifier: event.id, title: "곧 있을 일정", body: body, triggerDate: triggerDate)
    }
}
