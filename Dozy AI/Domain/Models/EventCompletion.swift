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
    var updatedAt: Date
    
    init(eventID: String) {
        self.eventID = eventID
        self.isCompleted = false
        self.updatedAt = Date()
    }
}
