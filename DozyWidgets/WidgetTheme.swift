//
//  WidgetTheme.swift
//  DozyWidgetsExtension
//
//  위젯의 배경을 메인 앱의 DozyBackgroundTheme 선택과 일치시키기.
//
//  메인 앱은 무거운 ambient view (MeshGradient / Blob blurred circle) 를 쓰지만,
//  위젯 extension 의 메모리/CPU budget 에선 부담이라 *시각적 유사한 LinearGradient* 만 사용.
//  사용자가 인지하는 톤 (system / 쿨 라벤더 / 따뜻한 핑크) 은 유지하면서 안전.
//

import SwiftUI

/// 위젯에서 사용할 background theme 정보.
/// 메인 앱의 `DozyBackgroundTheme` rawValue 를 App Group UserDefaults 에서 읽어 분기.
enum WidgetTheme {

    private static let appGroupID = "group.com.dozy-ai.shared"
    private static let storageKey = "iosBackgroundTheme"

    /// 메인 앱이 저장한 현재 테마. 키 없으면 .system.
    static func current() -> DozyBackgroundTheme {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let raw = defaults.string(forKey: storageKey) ?? DozyBackgroundTheme.defaultTheme.rawValue
        return DozyBackgroundTheme(rawValue: raw) ?? .defaultTheme
    }
}

extension DozyBackgroundTheme {

    /// 위젯의 `containerBackground` 에 적용할 ShapeStyle.
    /// 메인 앱의 풀 ambient view 를 그대로 옮기지 않고, 동일 hue 의 가벼운 그라디언트로 대체.
    @ViewBuilder
    var widgetBackground: some View {
        switch self {
        case .system:
            // 시스템 기본 — iOS 가 자동으로 라이트/다크 적응시켜주는 회색 톤.
            Color(.secondarySystemBackground)
        case .ambientMesh:
            // 쿨 라벤더 톤. 메인 앱 MeshGradient 의 평균 색조.
            LinearGradient(
                colors: [
                    Color(red: 0.49, green: 0.54, blue: 0.88).opacity(0.35),  // lavender
                    Color(red: 0.71, green: 0.74, blue: 0.92).opacity(0.20),  // pale lavender
                    Color(.secondarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blob:
            // 따뜻한 핑크 톤. 메인 앱 Blob 의 평균 색조.
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.42, blue: 0.62).opacity(0.30),  // pink
                    Color(red: 1.00, green: 0.69, blue: 0.77).opacity(0.20),  // pale pink
                    Color(.secondarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
