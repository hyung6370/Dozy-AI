//
//  DozyAppearance.swift
//  Dozy AI
//
//  iOS 앱의 ambient 배경 ViewModifier 모음. enum 정의 자체는 DozyBackgroundTheme.swift
//  로 분리 — widget extension 이 무거운 ambient view 의존성 없이 enum 만 import 할 수 있도록.
//

import SwiftUI

/// macOS 의 ThemedCardSurfaceModifier 와 동일 패턴 — material + tint + stroke 를 한 번에 적용.
/// AppStorage 의 "iosBackgroundTheme" 를 직접 읽어 호출처는 인자 없이 사용 가능.
struct DozyThemedCardSurface: ViewModifier {
    let cornerRadius: CGFloat

    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
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

    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
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

    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
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
