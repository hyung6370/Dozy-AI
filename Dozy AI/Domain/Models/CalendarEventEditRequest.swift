//
//  CalendarEventEditRequest.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import Foundation

struct CalendarEventEditRequest {
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
}
