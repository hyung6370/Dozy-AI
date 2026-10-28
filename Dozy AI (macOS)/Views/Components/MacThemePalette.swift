//
//  MacThemePalette.swift
//  Dozy AI (macOS)
//
//  테마(MacBackgroundTheme) × 라이트/다크 별 색 토큰 (#107).
//  뷰는 `@Environment(\.macTheme)` 로 받은 팔레트의 토큰만 쓴다. 테마 추가·조정은 이 파일에서 끝난다.
//
//  텍스트 위계는 루트(`.macThemed()`)의 `foregroundStyle(textPrimary)` 하나로 잡는다 — 자식의
//  `.secondary` / `.tertiary` 는 SwiftUI 가 현재 foreground 색에서 파생하므로 테마 텍스트 색이
//  2·3단계까지 자동으로 번진다. 명시적으로 다른 색이 필요한 곳(섹션 제목·강조)만 토큰을 쓴다.
//  의미색(완료 초록 · 경고 주황 · 위험 빨강 · 토/일 요일색 · 카테고리 색)은 테마와 무관하게 둔다.
//

import SwiftUI

struct MacThemePalette: Equatable {
    /// 강조색 — 버튼 · 토글 · 선택 · 아이콘 · 차트의 "정보" 계열. 루트 tint 로도 들어간다.
    let accent: Color
    /// 본문 텍스트. 루트 foregroundStyle. 기본 테마는 시스템 primary 그대로.
    let textPrimary: Color
    /// 설정 섹션 제목 · "지난 30일" 같은 그룹 라벨.
    let sectionTitle: Color
    /// 카드 채움색. 기본 테마는 머티리얼을 쓰므로 .clear, 테마 모드는 머티리얼 없이 이 색으로 채운다 —
    /// 머티리얼 위에 얹으면 배경 흐림에 묻혀 테마 색이 드러나지 않는다.
    let cardFill: Color
    /// 카드 외곽선.
    let cardStroke: Color
    /// 카드 아래 부드러운 그림자. 기본 테마는 .clear.
    let cardShadow: Color
    /// 기본 테마인지 — true 면 루트 foregroundStyle 을 걸지 않아 네이티브 룩을 그대로 둔다.
    let isSystem: Bool

    /// 강조색의 옅은 채움 (아이콘 배경 · 선택 배경).
    var accentSoft: Color { accent.opacity(0.12) }
    /// 강조색 테두리.
    var accentStroke: Color { accent.opacity(0.18) }

    // MARK: - 테마별 정의

    static func system(_ scheme: ColorScheme) -> MacThemePalette {
        MacThemePalette(
            accent: DozyColor.Brand.primary,
            textPrimary: .primary,
            sectionTitle: .secondary,
            cardFill: .clear,
            cardStroke: Color.primary.opacity(0.05),
            cardShadow: .clear,
            isSystem: true
        )
    }

    /// 저채도 라벤더 메시 배경 — 페리윙클 강조, 남색 계열 텍스트, 흰 반투명 카드.
    static func ambient(_ scheme: ColorScheme) -> MacThemePalette {
        let dark = scheme == .dark
        let accent = Color(hex: dark ? "#8E9CF0" : "#6F7FD9")
        return MacThemePalette(
            accent: accent,
            textPrimary: Color(hex: dark ? "#E8EAF6" : "#262A48"),
            sectionTitle: accent,
            cardFill: dark ? Color(hex: "#1A1D33").opacity(0.88) : Color(hex: "#F3F4FC").opacity(0.92),
            cardStroke: accent.opacity(dark ? 0.28 : 0.22),
            cardShadow: dark ? Color.black.opacity(0.45) : accent.opacity(0.14),
            isSystem: false
        )
    }

    /// 컬러 블롭 배경 — 보라 강조, 자주빛 텍스트, 조금 더 투명한 카드.
    static func blob(_ scheme: ColorScheme) -> MacThemePalette {
        let dark = scheme == .dark
        let accent = Color(hex: dark ? "#A78BFA" : "#8B6CF0")
        return MacThemePalette(
            accent: accent,
            textPrimary: Color(hex: dark ? "#F0EAFB" : "#2A2344"),
            sectionTitle: accent,
            cardFill: dark ? Color(hex: "#231B3B").opacity(0.88) : Color(hex: "#F6F1FF").opacity(0.9),
            cardStroke: accent.opacity(dark ? 0.3 : 0.24),
            cardShadow: dark ? Color.black.opacity(0.5) : accent.opacity(0.16),
            isSystem: false
        )
    }
}

extension MacBackgroundTheme {
    func palette(for scheme: ColorScheme) -> MacThemePalette {
        switch self {
        case .system:       return .system(scheme)
        case .ambientMesh:  return .ambient(scheme)
        case .blob:         return .blob(scheme)
        }
    }
}

// MARK: - Environment

private struct MacThemeKey: EnvironmentKey {
    static let defaultValue: MacThemePalette = .system(.light)
}

extension EnvironmentValues {
    /// 현재 테마 팔레트. `.macThemed()` 를 건 루트 아래에서 유효하고, 그 밖(환경 미주입)에서는 기본 테마 값.
    var macTheme: MacThemePalette {
        get { self[MacThemeKey.self] }
        set { self[MacThemeKey.self] = newValue }
    }
}

/// AppStorage 의 테마와 colorScheme 을 읽어 팔레트를 환경에 넣고, tint · 텍스트 색을 루트에 건다.
/// 메인 쉘 · 캘린더 단독 창 · 메뉴바 팝오버 루트에 한 번씩만 건다.
private struct MacThemedModifier: ViewModifier {
    @AppStorage("macBackgroundTheme")
    private var backgroundThemeRaw: String = MacBackgroundTheme.defaultTheme.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var palette: MacThemePalette {
        (MacBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme).palette(for: colorScheme)
    }

    func body(content: Content) -> some View {
        let p = palette
        content
            .environment(\.macTheme, p)
            .tint(p.accent)
            // 기본 테마는 시스템 텍스트 색을 그대로 — 변경 전과 같은 네이티브 룩.
            .foregroundStyle(p.isSystem ? AnyShapeStyle(.foreground) : AnyShapeStyle(p.textPrimary))
    }
}

extension View {
    func macThemed() -> some View {
        modifier(MacThemedModifier())
    }
}
