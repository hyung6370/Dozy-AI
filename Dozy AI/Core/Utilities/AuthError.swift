//
//  AuthError.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidCredential
    case noViewController
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential: return String(localized: "인증 정보를 가져올 수 없습니다.")
        case .noViewController: return String(localized: "화면 정보를 가져올 수 없습니다.")
        }
    }
}
