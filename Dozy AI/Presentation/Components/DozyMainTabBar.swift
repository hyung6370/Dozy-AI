//
//  DozyMainTabBar.swift
//  Dozy AI
//
//  v2.0.0 커스텀 메인 탭바. 디자인 토큰 기반.
//  - 시스템 TabView 의 lifecycle/NavigationStack 보존을 그대로 받기 위해
//    MainTabView 에선 TabView 를 유지하고 시스템 탭바만 숨긴 뒤
//    이 컴포넌트를 safeAreaInset(edge: .bottom) 으로 올린다.
//  - 가운데 슬롯은 "탭" 이 아니라 "액션 버튼"(일정 생성). MainTab enum 에 케이스를 추가하지 않고
//    별도 onCreateEvent 콜백으로 분리해서 탭 선택 상태와 분리한다.
//  - 햅틱: 탭 변경 .light / 같은 탭 재선택 .soft / 가운데 액션 .medium.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DozyMainTabBar: View {

    @Binding var selection: MainTab
    /// 같은 탭 재선택 시 호출. 스크롤 투 톱 등 후속 동작용.
    var onReselect: ((MainTab) -> Void)? = nil
    /// 가운데 액션 버튼(일정 생성) 탭 시 호출.
    var onCreateEvent: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var lottieTrigger: Int = 0

    // MARK: - Layout constants

    private let barHeight: CGFloat = 57
    private let actionButtonDiameter: CGFloat = 112
    private let actionButtonLift: CGFloat = 32  // 탭바 위로 솟아오르는 양 (작을수록 굴곡 안쪽으로)
    private let notchDiameter: CGFloat = 118
    private let notchDepth: CGFloat = 36

    /// safeAreaInset 으로 잡힐 layout height. actionButton 은 visual 만 위/아래로 흘러나오게 두고,
    /// inset 양 자체는 본체 두께 + 솟음으로 깔끔하게 잡는다.
    /// (각 탭 화면의 .contentMargins(.bottom, ..., for: .scrollContent) 가 가림 보정)
    private var totalHeight: CGFloat {
        barHeight + actionButtonLift
    }

    var body: some View {
        ZStack(alignment: .top) {
            barBackground
            tabsRow
            actionButton
        }
        .frame(height: totalHeight)
    }

    // MARK: - Background

    private var barBackground: some View {
        DozyTabBarShape(
            notchDiameter: notchDiameter,
            notchDepth: notchDepth,
            shoulder: 40
        )
        .fill(DozyColor.Background.primary)
        .overlay(
            DozyTabBarShape(
                notchDiameter: notchDiameter,
                notchDepth: notchDepth,
                shoulder: 40
            )
            .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 10, y: -2)
        .padding(.top, actionButtonLift)
        .ignoresSafeArea(edges: .bottom)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : DozyColor.separator
    }

    private var borderWidth: CGFloat {
        colorScheme == .dark ? 1.0 : 0.5
    }

    // MARK: - Tabs row

    /// MainTab 4개를 2 / 액션 / 2 로 배치.
    private var tabsRow: some View {
        let allTabs = MainTab.allCases
        let leftTabs = Array(allTabs.prefix(2))
        let rightTabs = Array(allTabs.suffix(2))

        return HStack(spacing: 0) {
            ForEach(leftTabs) { tab in
                tabButton(for: tab)
            }
            // 가운데 액션 슬롯 자리비움 (실제 버튼은 ZStack 상위에서 overlay).
            Color.clear
                .frame(width: notchDiameter)
            ForEach(rightTabs) { tab in
                tabButton(for: tab)
            }
        }
        .frame(height: barHeight)
        .padding(.top, actionButtonLift)
    }

    private func tabButton(for tab: MainTab) -> some View {
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

    // MARK: - Center action button

    private var actionButton: some View {
        Button {
            handleCreateEvent()
        } label: {
            LottiePlayer(
                name: "new-schedule",
                trigger: lottieTrigger,
                startsPaused: true
            )
            .frame(width: actionButtonDiameter, height: actionButtonDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 일정 만들기")
        .accessibilityAddTraits(.isButton)
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

    private func handleCreateEvent() {
        haptic(.medium)
        lottieTrigger &+= 1
        onCreateEvent()
    }

    private func haptic(_ style: HapticStyle) {
        #if canImport(UIKit)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:  generator = UIImpactFeedbackGenerator(style: .light)
        case .soft:   generator = UIImpactFeedbackGenerator(style: .soft)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        }
        generator.impactOccurred()
        #endif
    }

    private enum HapticStyle { case light, soft, medium }
}

// MARK: - Preview

#if DEBUG
private struct DozyMainTabBarPreviewHost: View {
    @State private var selection: MainTab = .home
    @State private var lastAction: String = "—"
    var body: some View {
        VStack(spacing: DozySpacing.lg) {
            Spacer()
            Text("Selected: \(selection.title)")
                .font(DozyFont.headline)
                .foregroundStyle(DozyColor.Text.primary)
            Text("Action: \(lastAction)")
                .font(DozyFont.subheadline)
                .foregroundStyle(DozyColor.Text.secondary)
            Spacer()
            DozyMainTabBar(
                selection: $selection,
                onReselect: { _ in lastAction = "reselect" },
                onCreateEvent: { lastAction = "create event" }
            )
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
