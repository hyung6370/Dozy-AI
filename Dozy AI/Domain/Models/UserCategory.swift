//
//  UserCategory.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/11/26.
//

import SwiftData
import Foundation

@Model
final class UserCategory {
    var id: String = UUID().uuidString   // 경량 마이그레이션 지원을 위해 프로퍼티 레벨 기본값
    var name: String = ""
    var emoji: String = "📌"
    var colorHex: String = "#8E8E93"
    var order: Int = 0
    var updatedAt: Date = Date()

    init(name: String, emoji: String, colorHex: String, order: Int = 0) {
        self.id = UUID().uuidString
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.order = order
        self.updatedAt = Date()
    }

    static let defaultName = "일반"
}
