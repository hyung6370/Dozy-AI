//
//  CancelNotificationUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation

final class CancelNotificationUseCase {
    
    private let service: NotificationServiceProtocol
    
    init(service: NotificationServiceProtocol) {
        self.service = service
    }
    
    func execute(identifier: String) {
        service.cancel(identifier: identifier)
    }
}
