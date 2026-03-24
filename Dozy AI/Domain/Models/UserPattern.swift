//
//  UserPattern.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class UserPattern {
    var id: UUID
    var weekday: Int
    var topCategories: [String]
    var peakHours: [Int]
    var averageTaskCount: Double
    var suggestion: String
    var lastUpdated: Date
    
    init(weekday: Int) {
        self.id = UUID()
        self.weekday = weekday
        self.topCategories = []
        self.peakHours = []
        self.averageTaskCount = 0
        self.suggestion = ""
        self.lastUpdated = Date()
    }
}
