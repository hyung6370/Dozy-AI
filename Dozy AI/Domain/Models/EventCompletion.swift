//
//  EventCompletion.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation
import SwiftData

@Model
final class EventCompletion {
    var eventID: String
    var isCompleted: Bool
    var eventDate: Date = Date.distantPast
    var updatedAt: Date

    init(eventID: String, eventDate: Date) {
        self.eventID = eventID
        self.isCompleted = false
        self.eventDate = eventDate
        self.updatedAt = Date()
    }
}
