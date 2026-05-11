//
//  DozyMainTabBar.swift
//  Dozy AI
//
//  v2.0.0 커스텀 메인 탭바. 디자인 토큰 기반.
//  - 시스템 TabView 의 lifecycle/NavigationStack 보존을 그대로 받기 위해
//    MainTabView 에선 TabView 를 유지하고 시스템 탭바만 숨긴 뒤
//    이 컴포넌트를 safeAreaInset(edge: .bottom) 으로 올린다.
//  - 햅틱: 탭 변경 시 light impact. 같은 탭 재선택 시 soft impact.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DozyMainTabBar: View {

    @Binding var selection: MainTab
    /// 같은 탭을 다시 탭했을 때 호출. 스크롤 투 톱 등 후속 동작용.
    var onReselect: ((MainTab) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                button(for: tab)
            }
        }
        .padding(.horizontal, DozySpacing.xs)
        .padding(.top, DozySpacing.xs)
        .padding(.bottom, DozySpacing.xxs)
        .background(barBackground)
    }

    // MARK: - Subviews

    private func button(for tab: MainTab) -> some View {
        let isSelected = selection == tab
        return Button {
            handleTap(tab, isReselect: isSelected)
        } label: {
            VStack(spacing: DozySpacing.xxs) {
                Image(tab.iconName(colorScheme: colorScheme, isSelected: isSelected))
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                Text(tab.title)
                    .font(DozyFont.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? DozyColor.Text.primary : DozyColor.Text.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DozySpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private var barBackground: some View {
        ZStack {
            DozyColor.Background.primary
                .opacity(0.92)
            Rectangle()
                .fill(DozyColor.separator)
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Interaction

    private func handleTap(_ tab: MainTab, isReselect: Bool) {
        if isReselect {
            haptic(.soft)
            onReselect?(tab)
            return
        }
        haptic(.light)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            selection = tab
        }
    }

    private func haptic(_ style: HapticStyle) {
        #if canImport(UIKit)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = UIImpactFeedbackGenerator(style: .light)
        case .soft:  generator = UIImpactFeedbackGenerator(style: .soft)
        }
        generator.impactOccurred()
        #endif
    }

    private enum HapticStyle { case light, soft }
}

// MARK: - Preview

#if DEBUG
private struct DozyMainTabBarPreviewHost: View {
    @State private var selection: MainTab = .home
    var body: some View {
        VStack(spacing: DozySpacing.lg) {
            Spacer()
            Text("Selected: \(selection.title)")
                .font(DozyFont.headline)
                .foregroundStyle(DozyColor.Text.primary)
            Spacer()
            DozyMainTabBar(selection: $selection, onReselect: { _ in })
        }
        .background(DozyColor.Background.grouped)
    }
}

#Preview("Light") {
    DozyMainTabBarPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DozyMainTabBarPreviewHost()
        .preferredColorScheme(.dark)
}
#endif
