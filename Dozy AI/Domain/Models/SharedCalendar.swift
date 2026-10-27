//
//  SharedCalendar.swift
//  Dozy AI
//

import Foundation

struct SharedCalendar: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let inviteCode: String?
    let inviteCodeExpiresAt: Date?
    let createdBy: String
    let createdAt: Date
    let imagePath: String?

    var isInviteCodeExpired: Bool {
        guard let inviteCodeExpiresAt else { return false }
        return inviteCodeExpiresAt < Date()
    }
}
