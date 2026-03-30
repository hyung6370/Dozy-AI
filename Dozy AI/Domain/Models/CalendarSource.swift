//
//  CalendarSource.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation

enum CalendarSource: String, Codable, CaseIterable, Hashable {
    case apple = "apple"
    case google = "google"
    case dozy = "dozy"
    
    var displayName: String {
        switch self {
        case .apple: return "Apple 캘린더"
        case .google: return "Google 캘린더"
        case .dozy: return "Dozy 캘린더"
        }
    }
    
    var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "globe"
        case .dozy: return "d.circle.fill"
        }
    }
}
