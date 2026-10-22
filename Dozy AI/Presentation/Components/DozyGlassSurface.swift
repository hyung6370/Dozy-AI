//
//  DozyGlassSurface.swift
//  Dozy AI
//
//  글라스 표면 모디파이어. iOS 26 은 Liquid Glass(`glassEffect`), 17/18 은 머티리얼 폴백,
//  "투명도 줄이기" 접근성 설정이면 불투명 표현으로 떨어진다.
//  탭바(DozyMainTabBar)와 선택 필이 쓴다.
//

import SwiftUI

enum DozyGlassStyle: Equatable { case regular, clear }

struct DozyGlassSurface<S: Shape>: ViewModifier {
    var shape: S
    var style: DozyGlassStyle = .regular
    var interactive: Bool = false
    var tint: Color? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(DozyColor.Background.primary.opacity(0.97), in: shape)
                .overlay(shape.stroke(DozyColor.separator, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        } else if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(DozyColor.Surface.primary.opacity(0.35), in: shape)   // 머티리얼이 너무 비치지 않게 한 겹
                .overlay(
                    shape.stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.6), lineWidth: 0.8)
                        .blendMode(.plusLighter)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.10), radius: 18, y: 8)
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass: Glass = style == .clear ? .clear : .regular
        if interactive { glass = glass.interactive() }
        if let tint { glass = glass.tint(tint) }
        return glass
    }
}

extension View {
    func dozyGlassSurface<S: Shape>(in shape: S, style: DozyGlassStyle = .regular,
                                    interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(DozyGlassSurface(shape: shape, style: style, interactive: interactive, tint: tint))
    }
}
