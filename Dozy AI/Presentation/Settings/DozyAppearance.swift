//
//  DozyAppearance.swift
//  Dozy AI
//
//  iOS 앱의 ambient 배경 테마 선택. macOS 의 MacBackgroundTheme 와 동일 패턴이며,
//  iOS 별도 AppStorage key "iosBackgroundTheme" 로 저장된다.
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
        case .system:       return "기본"
        case .ambientMesh:  return "Ambient"
        case .blob:         return "Blob"
        }
    }

    var summary: String {
        switch self {
        case .system:       return "iOS 표준 배경 — 어떤 ambient 도 깔지 않습니다."
        case .ambientMesh:  return "저채도 메시 그라디언트 — 가장 차분한 무드."
        case .blob:         return "컬러 블롭 — 생동감 있는 ambient."
        }
    }

    static let storageKey = "iosBackgroundTheme"
    static let defaultTheme: DozyBackgroundTheme = .system

    // MARK: - Card surface

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

/// macOS 의 ThemedCardSurfaceModifier 와 동일 패턴 — material + tint + stroke 를 한 번에 적용.
/// AppStorage 의 "iosBackgroundTheme" 를 직접 읽어 호출처는 인자 없이 사용 가능.
struct DozyThemedCardSurface: ViewModifier {
    let cornerRadius: CGFloat

    @AppStorage(DozyBackgroundTheme.storageKey)
    private var themeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var theme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: themeRaw) ?? .defaultTheme
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            // 1) 항상 solid groupedRow base — 카드 자체 시인성 보장
            .background(DozyColor.Background.groupedRow, in: shape)
            // 2) 테마 tint overlay — system 은 .clear 라 영향 없음
            .background(theme.cardTint, in: shape)
            .overlay(shape.strokeBorder(theme.cardStroke, lineWidth: 1))
    }
}

extension View {
    /// 테마-적응 카드 표면. DozyListSection 등 카드 패턴의 .background 대체.
    func dozyThemedCardSurface(cornerRadius: CGFloat) -> some View {
        modifier(DozyThemedCardSurface(cornerRadius: cornerRadius))
    }

    /// 카드 외곽 stroke 만 적용. 기존 .background(.regularMaterial, in: RoundedRectangle(...)) 패턴 직후에 추가.
    /// system 테마는 매우 옅은 회색이라 시각 변화 거의 없음, ambient/blob 에서는 테마 색 stroke.
    func dozyThemedCardBorder(cornerRadius: CGFloat) -> some View {
        modifier(DozyThemedCardBorderModifier(cornerRadius: cornerRadius))
    }

    /// 화면 root 에 적용하는 themed shell background.
    /// - parameter systemBackground: 기본(system) 테마일 때 깔 색. nil 이면 no-op (호출처 default 유지).
    func dozyThemedShellBackground(systemBackground: Color? = nil) -> some View {
        modifier(DozyThemedShellBackgroundModifier(systemBackground: systemBackground))
    }
}

private struct DozyThemedCardBorderModifier: ViewModifier {
    let cornerRadius: CGFloat

    @AppStorage(DozyBackgroundTheme.storageKey)
    private var themeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var theme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: themeRaw) ?? .defaultTheme
    }

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(theme.cardStroke, lineWidth: 1)
        )
    }
}

private struct DozyThemedShellBackgroundModifier: ViewModifier {
    let systemBackground: Color?

    @AppStorage(DozyBackgroundTheme.storageKey)
    private var themeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var theme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: themeRaw) ?? .defaultTheme
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch theme {
        case .system:
            if let systemBackground {
                content.background(systemBackground)
            } else {
                content
            }
        case .ambientMesh, .blob:
            content.background(DozyShellBackgroundView(theme: theme))
        }
    }
}

/// 현재 선택된 테마에 맞춰 앱 전체 배경을 렌더하는 view.
/// system 은 EmptyView — 호출처가 자체 default 배경을 유지하도록.
struct DozyShellBackgroundView: View {
    let theme: DozyBackgroundTheme

    var body: some View {
        switch theme {
        case .system:
            EmptyView()
        case .ambientMesh:
            AmbientMeshBackgroundView()
        case .blob:
            BlobBackgroundView(intensity: 0.6)
                .ignoresSafeArea()
        }
    }
}
