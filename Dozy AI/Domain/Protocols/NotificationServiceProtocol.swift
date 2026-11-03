//
//  NotificationServiceProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

protocol NotificationServiceProtocol {
    func requestAuthorization() async -> Bool
    func schedule(identifier: String, title: String, body: String, triggerDate: Date)
    func cancel(identifier: String)
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)

extension NotificationServiceProtocol {
    func requestAuthorization() -> AnyPublisher<Bool, Never> {
        .bridge { await self.requestAuthorization() }
    }
}
