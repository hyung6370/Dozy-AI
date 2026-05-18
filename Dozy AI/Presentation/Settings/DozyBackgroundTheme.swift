//
//  DozyBackgroundTheme.swift
//  Dozy AI
//
//  iOS 앱과 위젯이 공유하는 배경 테마 enum. 무거운 ambient view 와 ViewModifier 들은
//  DozyAppearance.swift 에 분리 — widget extension 은 enum 만 필요.
//

import SwiftUI

enum DozyBackgroundTheme: String, CaseIterable, Identifiable {
    /// 시스템 기본 — 어떤 ambient 배경도 깔지 않는다.
    case system
    /// 저채도 MeshGradient — 차분한 라벤더 ↔ 쿨 그레이.
    case ambientMesh
    /// 컬러 블롭 — 생동감 있는 ambient.
    case blob

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:       return String(localized: "기본")
        case .ambientMesh:  return "Ambient"
        case .blob:         return "Blob"
        }
    }

    var summary: String {
        switch self {
        case .system:       return String(localized: "iOS 표준 배경 — 어떤 ambient 도 깔지 않습니다.")
        case .ambientMesh:  return String(localized: "저채도 메시 그라디언트 — 가장 차분한 무드.")
        case .blob:         return String(localized: "컬러 블롭 — 생동감 있는 ambient.")
        }
    }

    static let storageKey = "iosBackgroundTheme"
    static let defaultTheme: DozyBackgroundTheme = .system

    /// 위젯과 메인 앱이 공유할 App Group identifier.
    static let appGroupID = "group.com.dozy-ai.shared"

    /// `@AppStorage(store:)` 에 넘길 shared UserDefaults — 위젯도 같은 store 를 봄.
    /// suite 가 nil 인 경우 (entitlement 누락 등) standard 로 fallback.
    static let sharedDefaults: UserDefaults =
        UserDefaults(suiteName: appGroupID) ?? .standard

    /// 기존 사용자의 standard UserDefaults 에 있던 테마를 App Group 으로 1회 이전.
    /// 신규 사용자는 App Group 에서 default 값으로 시작 — 영향 없음.
    private static let hasMigratedThemeKey = "app.hasMigratedThemeToAppGroup_v1"

    static func migrateThemeStorageIfNeeded() {
        let standard = UserDefaults.standard
        if standard.bool(forKey: hasMigratedThemeKey) { return }

        if let oldValue = standard.string(forKey: storageKey),
           sharedDefaults.string(forKey: storageKey) == nil {
            sharedDefaults.set(oldValue, forKey: storageKey)
        }
        standard.set(true, forKey: hasMigratedThemeKey)
    }

    // MARK: - Card surface (iOS 앱 카드 hex tint)

    /// 카드 색조. groupedRow solid 위에 얹어 명확한 시각 차이를 만든다.
    /// Ambient = 쿨 라벤더 / Blob = 따뜻한 핑크 — hue 자체를 분리해서 두 테마가 한눈에 구분.
    var cardTint: Color {
        switch self {
        case .system:
            return .clear
        case .ambientMesh:
            return Color(hex: "#7C8AE0").opacity(0.22)  // cool lavender
        case .blob:
            return Color(hex: "#FF6B9D").opacity(0.22)  // warm pink
        }
    }

    /// 카드 외곽 stroke.
    var cardStroke: Color {
        switch self {
        case .system:       return Color.primary.opacity(0.05)
        case .ambientMesh:  return Color(hex: "#7C8AE0").opacity(0.4)
        case .blob:         return Color(hex: "#FF6B9D").opacity(0.45)
        }
    }
}
