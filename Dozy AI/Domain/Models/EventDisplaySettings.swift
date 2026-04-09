//
//  EventDisplaySettings.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import Foundation
import SwiftData

@Model
final class EventDisplaySettings {
    @Attribute(.unique) var eventID: String
    var priority: Int = 0
    var isPinned: Bool = false
    var category: String = "일반"

    init(eventID: String, priority: Int = 0, isPinned: Bool = false, category: String = "일반") {
        self.eventID = eventID
        self.priority = priority
        self.isPinned = isPinned
        self.category = category
    }
}
