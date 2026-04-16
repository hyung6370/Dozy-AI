//
//  AuthUser.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation

struct AuthUser {
    let id: String
    let email: String?
    let displayName: String?
    let provider: AuthProvider
}

enum AuthProvider {
    case apple
    case google
}
