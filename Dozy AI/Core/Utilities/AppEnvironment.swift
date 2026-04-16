//
//  AppEnvironment.swift
//  Dozy AI
//

import Foundation

#if DEBUG
enum AppEnvironment: String {
    case development
    case production

    var displayName: String {
        switch self {
        case .development: return "개발 (Dev)"
        case .production:  return "운영 (Prod)"
        }
    }

    private static let userDefaultsKey = "selected_app_environment"

    static var current: AppEnvironment {
        get {
            let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
            return AppEnvironment(rawValue: raw) ?? .development
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
}
#endif
