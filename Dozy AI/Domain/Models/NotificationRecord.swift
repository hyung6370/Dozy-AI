//
//  NotificationRecord.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import Foundation
import SwiftData

@Model
final class NotificationRecord {
    @Attribute(.unique) var id: UUID
    var eventID: String
    var eventTitle: String
    var body: String
    var deliveryDate: Date
    var isRead: Bool
    
    init(eventID: String, eventTitle: String, body: String, deliveryDate: Date) {
        self.id = UUID()
        self.eventID = eventID
        self.eventTitle = eventTitle
        self.body = body
        self.deliveryDate = deliveryDate
        self.isRead = false
    }
}
