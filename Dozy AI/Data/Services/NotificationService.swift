//
//  NotificationService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine
import UserNotifications

final class NotificationService: NotificationServiceProtocol {
    
    func requestAuthorization() -> AnyPublisher<Bool, Never> {
        Future { promise in
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, _ in
                promise(.success(granted))
            }
        }
        // Swift 6: 시스템 콜백 큐에서 끝난다 — 메인 액터로 추론된 하류 클로저(sink · flatMap)가 런타임 격리 검사에 걸리지 않게 메인으로 넘긴다.
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func schedule(identifier: String, title: String, body: String, triggerDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
