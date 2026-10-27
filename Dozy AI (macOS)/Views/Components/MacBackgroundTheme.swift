//
//  MacBackgroundTheme.swift
//  Dozy AI (macOS)
//
//  메인 쉘(NavigationSplitView)의 ambient 배경 테마 선택. AppStorage 키
//  "macBackgroundTheme" 으로 영구 저장되며, 설정 탭에서 사용자가 변경한다.
//

import SwiftUI

enum MacBackgroundTheme: String, CaseIterable, Identifiable {
    /// 변경 전 기본 — 사이드바 머티리얼 + 시스템 detail 배경. 어떤 커스텀 배경도 깔지 않음.
    case system
    /// 저채도 MeshGradient — 차분한 라벤더 ↔ 쿨 그레이 무드. 현재 기본값.
    case ambientMesh
    /// 컬러 블롭 — IntroView 무드를 다운톤한 영구 노출용 버전.
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
        case .system:       return String(localized: "macOS 표준 배경 — 사이드바 머티리얼 그대로.")
        case .ambientMesh:  return String(localized: "저채도 메시 그라디언트 — 가장 차분한 무드.")
        case .blob:         return String(localized: "컬러 블롭 — 생동감 있는 ambient.")
        }
    }

    /// 기본값. 신규 사용자/AppStorage 미설정 시 이 값으로 초기화된다.
    static let defaultTheme: MacBackgroundTheme = .ambientMesh

    // MARK: - Card surface

    /// 카드 베이스 머티리얼. 배경 무드에 따라 머티리얼 계열을 다르게 가져간다.
    /// `.ultraThinMaterial` 은 텍스트 가독성이 떨어져 사용하지 않는다 — 모든 테마에서
    /// `.regularMaterial` 이상의 불투명도를 유지해 본문 대비를 보장한다.
    var cardMaterial: Material {
        switch self {
        case .system:       return .regularMaterial
        case .ambientMesh:  return .regularMaterial
        case .blob:         return .regularMaterial
        }
    }

    /// 머티리얼 위에 얹는 옅은 색조. 배경과 일관된 라벤더/핑크 계열로 카드를
    /// 살짝 물들여 단조로움을 줄인다. system 은 native 머티리얼 그대로 유지.
    var cardTint: Color {
        switch self {
        case .system:
            return .clear
        case .ambientMesh:
            return (Color(hex: "#7C8AE0") ?? .clear).opacity(0.05)
        case .blob:
            return (Color(hex: "#A78BFA") ?? .clear).opacity(0.06)
        }
    }

    /// 카드 외곽 stroke. 배경에 카드가 묻히지 않도록 적당히 분리.
    var cardStroke: Color {
        switch self {
        case .system:       return Color.primary.opacity(0.05)
        case .ambientMesh:  return Color.primary.opacity(0.07)
        case .blob:         return Color.primary.opacity(0.07)
        }
    }

    // MARK: - Calendar event chip

    /// 캘린더 일정 칩(카테고리 색 틴트)의 알파. 색이 있는 배경 위에선 살짝 더 진하게.
    var eventChipColorOpacity: Double {
        switch self {
        case .system:                   return 0.22
        case .ambientMesh, .blob:       return 0.32
        }
    }

    /// 일정 칩 아래 깔리는 안정 표면. system 은 배경이 단색이라 불필요해서 nil.
    /// ambient/blob 은 material 위에 색조를 올려 텍스트 대비를 보장한다.
    var eventChipSubstrate: Material? {
        switch self {
        case .system:                   return nil
        case .ambientMesh, .blob:       return .regularMaterial
        }
    }
}

/// 선택된 테마에 맞춰 배경 뷰를 렌더링하는 헬퍼. `.system` 의 경우 EmptyView 를 반환하므로
/// 호출 측에서 `.scrollContentBackground(.hidden)` 등 ovveride 를 분기해야 한다.
struct MacShellBackgroundView: View {
    let theme: MacBackgroundTheme

    var body: some View {
        switch theme {
        case .system:
            EmptyView()
        case .ambientMesh:
            AmbientMeshBackgroundView()
                .ignoresSafeArea()
        case .blob:
            BlobBackgroundView(intensity: 0.6)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Themed card surface

/// 메인 쉘 안의 모든 카드(`.regularMaterial` + RoundedRectangle 패턴) 에 일괄 적용하는
/// modifier. 현재 선택된 `MacBackgroundTheme` 에 맞춰 머티리얼·색조·테두리를 함께 갈아낀다.
private struct ThemedCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @AppStorage("macBackgroundTheme")
    private var backgroundThemeRaw: String = MacBackgroundTheme.defaultTheme.rawValue

    private var theme: MacBackgroundTheme {
        MacBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background(theme.cardMaterial, in: shape)
            .background(theme.cardTint, in: shape)
            .overlay(shape.strokeBorder(theme.cardStroke, lineWidth: 1))
    }
}

extension View {
    /// 테마-적응 카드 표면. 기존 `.background(.regularMaterial, in: RoundedRectangle(...))`
    /// (선택적으로 `.overlay(...strokeBorder...)`) 패턴을 통째로 대체한다.
    func themedCardSurface(cornerRadius: CGFloat) -> some View {
        modifier(ThemedCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// 캘린더 일정 칩 배경. 기존 `.background(color.opacity(0.22), in: RoundedRectangle(...))`
    /// 패턴을 대체. ambient/blob 테마에선 머티리얼 서브스트레이트 위에 색조를 얹어
    /// 색이 있는 배경 너머에서도 칩 텍스트 대비를 유지한다.
    func themedEventChipBackground(color: Color, cornerRadius: CGFloat) -> some View {
        modifier(ThemedEventChipBackgroundModifier(color: color, cornerRadius: cornerRadius))
    }
}

private struct ThemedEventChipBackgroundModifier: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat

    @AppStorage("macBackgroundTheme")
    private var backgroundThemeRaw: String = MacBackgroundTheme.defaultTheme.rawValue

    private var theme: MacBackgroundTheme {
        MacBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content.background {
            ZStack {
                if let substrate = theme.eventChipSubstrate {
                    shape.fill(substrate)
                }
                shape.fill(color.opacity(theme.eventChipColorOpacity))
            }
        }
    }
}
