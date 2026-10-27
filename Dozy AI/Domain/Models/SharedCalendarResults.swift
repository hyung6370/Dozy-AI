//
//  SharedCalendarResults.swift
//  Dozy AI
//

import Foundation

struct SharedCalendarCreationResult {
    let calendarID: String
    let inviteCode: String
    let inviteCodeExpiresAt: Date
}

struct SharedCalendarJoinResult {
    let calendarID: String
}

struct SharedCalendarInviteCodeResult {
    let inviteCode: String
    let inviteCodeExpiresAt: Date
}
