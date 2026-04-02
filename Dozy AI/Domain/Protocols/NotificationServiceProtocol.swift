//
//  NotificationServiceProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import Combine

protocol NotificationServiceProtocol {
    func requestAuthorization() -> AnyPublisher<Bool, Never>
    func schedule(identifier: String, title: String, body: String, triggerDate: Date)
    func cancel(identifier: String)
}
