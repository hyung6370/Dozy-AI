//
//  SharedCalendarMember.swift
//  Dozy AI
//

import Foundation

enum SharedCalendarRole: String, Codable, Hashable {
    case owner
    case member
}

struct SharedCalendarMember: Identifiable, Codable, Hashable {
    let sharedCalendarID: String
    let userID: String
    let role: SharedCalendarRole
    let joinedAt: Date

    var id: String { "\(sharedCalendarID)/\(userID)" }

    var isOwner: Bool { role == .owner }
}
