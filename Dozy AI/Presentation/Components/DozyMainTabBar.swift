//
//  DozyMainTabBar.swift
//  Dozy AI
//
//  플로팅 Liquid Glass 탭바. 캡슐 글라스 안에 [홈 · 캘린더 · (+) · 인사이트 · 설정] 5개 슬롯과 선택 인디케이터 필이 놓인다.
//  가운데 슬롯은 "탭" 이 아니라 "액션"(일정 생성) — 필이 옮겨가지 않고 누르면 onCreateEvent 만 부른다.
//
//  선택 필: 캡슐 + iOS 26 `glassEffect(.regular)` 진짜 유리(17/18 은 머티리얼 폴백), 탭 아이콘·라벨 뒤 레이어.
//  탭 전환: 목적지로 스프링(0.35 / 0.65) 슬라이드하며 이동 중 세로로 조금 부풀었다(1.06×1.22) 도착하며 가라앉는다.
//  드래그(물방울): 필이 손가락을 연속으로 따라오며 1.15×1.3 으로 부풀고 바도 1.03 커진다. 지나가는 탭이 하이라이트되고
//  놓으면 손가락 아래 탭으로 스냅·선택. 액션 슬롯 위에서 놓으면 원래 선택으로 되돌아간다.
//  스크롤 축소(isCompact): 알약이 좁아지고 라벨이 접힌다 — DozyTabBarChrome 이 구동.
//
//  시스템 TabView 의 lifecycle/NavigationStack 보존은 그대로 받기 위해 MainTabView 는 TabView 를 유지하고
//  시스템 탭바만 숨긴 뒤 이 바를 overlay(alignment: .bottom) 로 띄운다.
//

import SwiftUI

// MARK: - Metrics

enum DozyTabBarMetrics {
    static let itemHeight: CGFloat = 52
    static let innerPadding: CGFloat = 6
    static let horizontalMargin: CGFloat = 20
    static let bottomMargin: CGFloat = 8
    static let iconSize: CGFloat = 24
    static let labelSize: CGFloat = 10
    static let actionDiameter: CGFloat = 40

    // 축소(스크롤 중) 치수 — 알약이 좁아지고 라벨이 접힌다.
    static let compactItemHeight: CGFloat = 40
    static let compactInnerPadding: CGFloat = 4
    static let compactHorizontalMargin: CGFloat = 44
    static let compactIconSize: CGFloat = 22
    static let compactActionDiameter: CGFloat = 32

    static var barHeight: CGFloat { itemHeight + innerPadding * 2 }

    /// 스크롤 콘텐츠 하단 여백 — 떠 있는 바가 마지막 콘텐츠를 덮지 않게 둔다.
    static var scrollClearance: CGFloat { barHeight + bottomMargin + 12 }
}

// MARK: - Slot

/// 캡슐 안 슬롯 — 탭 4개 사이에 액션 슬롯 1개.
enum DozyTabBarSlot: Hashable {
    case tab(MainTab)
    case action

    var tab: MainTab? {
        if case .tab(let t) = self { return t }
        return nil
    }

    /// 홈 · 캘린더 · (+) · 인사이트 · 설정
    static let ordered: [DozyTabBarSlot] = [.tab(.home), .tab(.calendar), .action, .tab(.insight), .tab(.settings)]

    static func index(of tab: MainTab) -> Int {
        ordered.firstIndex(of: .tab(tab)) ?? 0
    }
}

// MARK: - Bar

struct DozyMainTabBar: View {
    @Binding var selection: MainTab
    var isCompact: Bool = false
    /// 같은 탭 재선택 시 호출. 스크롤 투 톱 등 후속 동작용.
    var onReselect: (MainTab) -> Void = { _ in }
    /// 가운데 액션 슬롯(일정 생성) 탭 시 호출.
    var onCreateEvent: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 진행 중인 드래그(트랙 좌표계 x). nil 이면 드래그 아님.
    @State private var drag: DragState?
    /// 손가락이 눌린 채 아직 움직이지 않은 슬롯(누름 피드백용).
    @State private var pressedSlot: DozyTabBarSlot?
    @State private var trackWidth: CGFloat = 0
    /// 탭으로 전환할 때마다 +1 — 필 '이동 부풀기' 키프레임 트리거(드래그 스냅은 lift 가 이미 커져 있어 제외).
    @State private var travelTrigger = 0
    /// 액션 슬롯 탭 횟수 — 햅틱·아이콘 바운스 트리거.
    @State private var actionTrigger = 0

    private struct DragState: Equatable {
        var x: CGFloat
    }

    private var isDragging: Bool { drag != nil }
    private let slots = DozyTabBarSlot.ordered

    /// 필 이동 곡선 — 점성·탄력이 느껴지는 스프링. 탭 전환·드래그 스냅 공통. (0.35 → 0.48: 살짝 느긋하게)
    static let liquid: Animation = .spring(response: 0.48, dampingFraction: 0.7, blendDuration: 0.1)

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 20) { bar }
            } else {
                bar
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(slots, id: \.self) { slot in
                switch slot {
                case .tab(let tab):
                    DozyTabBarItem(tab: tab,
                                   isSelected: highlightedTab == tab,
                                   isPressed: pressedSlot == slot,
                                   isCompact: isCompact) { select(tab) }
                case .action:
                    DozyTabBarActionItem(isPressed: pressedSlot == .action,
                                         isCompact: isCompact,
                                         bounceTrigger: actionTrigger) { fireAction() }
                }
            }
        }
        .background { indicator }   // 아이템 뒤 레이어
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
        .contentShape(Rectangle())
        .gesture(pressDragGesture)
        .padding(isCompact ? DozyTabBarMetrics.compactInnerPadding : DozyTabBarMetrics.innerPadding)
        .dozyGlassSurface(in: Capsule(), style: .regular)
        // 드래그 중엔 바가 살짝 부풀어 오른다(확대 + 그림자 강화) — 손가락이 유리를 들어 올리는 느낌.
        .scaleEffect(isDragging && !reduceMotion ? 1.03 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.10 : 0.06), radius: isDragging ? 18 : 14, y: isDragging ? 8 : 6)
        .animation(Self.liquid, value: isDragging)
        .padding(.horizontal, isCompact ? DozyTabBarMetrics.compactHorizontalMargin : DozyTabBarMetrics.horizontalMargin)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: isCompact)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: selection)
        .sensoryFeedback(.impact(weight: .medium), trigger: actionTrigger)
        .sensoryFeedback(.selection, trigger: highlightedTab) { _, _ in drag != nil }   // 드래그로 탭을 지날 때 틱
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("main_tabbar")
    }

    /// 드래그 중이면 손가락 아래 탭, 아니면 선택 탭.
    private var highlightedTab: MainTab {
        guard let drag else { return selection }
        return tab(at: drag.x)
    }

    private var slotWidth: CGFloat { trackWidth / CGFloat(max(slots.count, 1)) }

    private func slot(at x: CGFloat) -> DozyTabBarSlot? {
        guard slotWidth > 0 else { return nil }
        let index = min(max(Int(x / slotWidth), 0), slots.count - 1)
        return slots[index]
    }

    /// 손가락 아래 탭. 액션 슬롯 위면 현재 선택 유지(필이 그 자리로 가지 않는다).
    private func tab(at x: CGFloat) -> MainTab {
        slot(at: x)?.tab ?? selection
    }

    // MARK: 인디케이터

    /// 슬롯 폭이 균등하므로 인덱스 × 폭으로 자리를 잡는다. 드래그 중에는 손가락 x 를 그대로 따라간다(트랙 안으로 클램프, 즉시).
    /// 탭 전환·스냅은 select()/onEnded 의 withAnimation(liquid) 이 offset 을 보간해 미끄러진다.
    private var indicator: some View {
        GeometryReader { geo in
            let slot = geo.size.width / CGFloat(max(slots.count, 1))
            let restingX = slot * CGFloat(DozyTabBarSlot.index(of: selection))
            let x = drag.map { min(max($0.x - slot / 2, 0), geo.size.width - slot) } ?? restingX
            DozyIndicatorPill(lift: isDragging && !reduceMotion,
                              travelTrigger: travelTrigger,
                              travels: !reduceMotion)
                .frame(width: slot, height: geo.size.height)
                .offset(x: x)
        }
        // 이동·드래그 중 부푼 필이 바 위아래로 살짝 나올 수 있게 트랙 바깥 12pt 까지 허용(가로는 offset 클램프가 막는다).
        .clipShape(Capsule().inset(by: -12))
    }

    // MARK: 제스처

    /// 탭과 드래그를 한 제스처로 다룬다(버튼과 동시 인식하면 손가락이 출발 탭을 벗어날 때 드래그가 끊긴다).
    /// 8pt 미만 움직임은 누름 → 놓으면 탭 선택(액션 슬롯이면 액션). 그 이상 움직이면 필이 손가락을 따라오고, 놓으면 손가락 아래 탭으로 스냅한다.
    private var pressDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let moved = abs(value.translation.width) >= 8 || abs(value.translation.height) >= 8
                if drag == nil && !moved {
                    pressedSlot = slot(at: value.startLocation.x)
                    return
                }
                if drag == nil { pressedSlot = nil }
                drag = DragState(x: value.location.x)
            }
            .onEnded { value in
                pressedSlot = nil
                if drag == nil {
                    switch slot(at: value.startLocation.x) {
                    case .tab(let tab): select(tab)
                    case .action:       fireAction()
                    case nil:           break
                    }
                    return
                }
                let target = tab(at: value.location.x)
                withAnimation(reduceMotion ? nil : Self.liquid) {
                    drag = nil
                    selection = target
                }
            }
    }

    private func select(_ tab: MainTab) {
        guard selection != tab else { onReselect(tab); return }   // 재터치 — 드래그로 같은 탭에 놓는 경우는 onEnded 가 select 를 거치지 않아 제외
        if reduceMotion {
            selection = tab
        } else {
            travelTrigger &+= 1   // 이동 부풀기 키프레임 시작
            withAnimation(Self.liquid) { selection = tab }
        }
    }

    private func fireAction() {
        actionTrigger &+= 1
        onCreateEvent()
    }
}

// MARK: - 탭 아이템

/// 글라스 탭바의 탭 1개. 아이콘(Assets 의 Light/Dark · selected 변형) + 라벨. 선택되면 아이콘이 한 번 튀어 오르고 selected 에셋으로 크로스페이드한다.
/// 터치는 바(DozyMainTabBar)가 한 제스처로 처리하므로 여기는 그리기 + 접근성(버튼 트레이트·기본 액션)만 맡는다.
private struct DozyTabBarItem: View {
    let tab: MainTab
    let isSelected: Bool
    var isPressed: Bool = false
    var isCompact: Bool = false
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            icon
                .frame(width: isCompact ? DozyTabBarMetrics.compactIconSize : DozyTabBarMetrics.iconSize,
                       height: isCompact ? DozyTabBarMetrics.compactIconSize : DozyTabBarMetrics.iconSize)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: isSelected) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(isSelected && !reduceMotion ? 1.18 : 1, duration: 0.14, spring: .snappy(duration: 0.14))
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy(duration: 0.4))
                    }
                }
            Text(tab.title)
                .font(.system(size: DozyTabBarMetrics.labelSize, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .opacity(isCompact ? 0 : 1)
                .frame(height: isCompact ? 0 : DozyTabBarMetrics.labelSize + 4)
                .clipped()
        }
        // 머티리얼(17/18 폴백) 위에서 `Color.secondary` 는 vibrancy 로 그려져 밝은 배경에서 사라진다 → UIKit 색을 직접 쓴다.
        .foregroundStyle(isSelected ? Color(.label) : Color(.secondaryLabel))
        .frame(maxWidth: .infinity)
        .frame(height: isCompact ? DozyTabBarMetrics.compactItemHeight : DozyTabBarMetrics.itemHeight)
        // 누르는 동안 살짝 눌리고 놓으면 되돌아온다 — 글라스를 손가락으로 누르는 감각.
        .scaleEffect(isPressed ? 0.92 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect() }
        .accessibilityIdentifier(tab.accessibilityID)   // UI 테스트 셀렉터(app.buttons["tab_home"] 등)
    }

    /// 비선택·선택 에셋을 겹쳐 두고 불투명도로 크로스페이드한다 — 이미지 교체가 튀지 않는다.
    private var icon: some View {
        ZStack {
            Image(tab.iconName(colorScheme: colorScheme, isSelected: false))
                .renderingMode(.original).resizable().scaledToFit()
                .opacity(isSelected ? 0 : 1)
            Image(tab.iconName(colorScheme: colorScheme, isSelected: true))
                .renderingMode(.original).resizable().scaledToFit()
                .opacity(isSelected ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 액션 아이템 (일정 생성)

/// 가운데 슬롯. 브랜드 색 원 안의 + 아이콘. 탭이 아니라 액션이라 선택 상태가 없다.
private struct DozyTabBarActionItem: View {
    var isPressed: Bool = false
    var isCompact: Bool = false
    var bounceTrigger: Int = 0
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var diameter: CGFloat {
        isCompact ? DozyTabBarMetrics.compactActionDiameter : DozyTabBarMetrics.actionDiameter
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [DozyColor.Brand.primary, DozyColor.Brand.secondary],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: DozyColor.Brand.primary.opacity(0.35), radius: 8, y: 3)
            Image(systemName: "plus")
                .font(.system(size: isCompact ? 16 : 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: bounceTrigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(reduceMotion ? 1 : 1.18, duration: 0.14, spring: .snappy(duration: 0.14))
                SpringKeyframe(1, duration: 0.4, spring: .bouncy(duration: 0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isCompact ? DozyTabBarMetrics.compactItemHeight : DozyTabBarMetrics.itemHeight)
        .scaleEffect(isPressed ? 0.9 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("새 일정 만들기")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityIdentifier("btn_create_event")
    }
}

// MARK: - 인디케이터 필

/// 선택 필 — 시스템 탭바 인디케이터처럼: 캡슐 유리. iOS 26 은 `glassEffect(.regular.interactive())` 진짜 Liquid Glass,
/// 17/18 은 `.ultraThinMaterial` + 얇은 보더 폴백. 라이트 · 다크 같은 모양 — 다크는 유리 틴트만 살짝 밝힌다.
///  • 이동(`travelTrigger`): 출발하며 세로 1.22·가로 1.06 으로 들렸다가 도착하며 바운스로 가라앉는다.
///  • 드래그(`lift`): 손가락이 누르는 동안 1.15×1.3 으로 부풀어 물방울처럼 바 밖으로 살짝 나온다.
private struct DozyIndicatorPill: View {
    var lift: Bool = false
    var travelTrigger: Int = 0
    var travels: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    private struct Bulge {
        var x: CGFloat = 1
        var y: CGFloat = 1
    }

    var body: some View {
        glass
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .scaleEffect(x: lift ? 1.15 : 1, y: lift ? 1.3 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: lift)    // 낮은 감쇠 — 살짝 출렁이며 부푼다
            .keyframeAnimator(initialValue: Bulge(), trigger: travelTrigger) { view, b in
                view.scaleEffect(x: b.x, y: b.y)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    SpringKeyframe(travels ? 1.06 : 1, duration: 0.14, spring: .snappy(duration: 0.14))
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy(duration: 0.4, extraBounce: 0.08))
                }
                KeyframeTrack(\.y) {
                    SpringKeyframe(travels ? 1.22 : 1, duration: 0.14, spring: .snappy(duration: 0.14))
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy(duration: 0.4, extraBounce: 0.08))
                }
            }
            .accessibilityHidden(true)
    }

    /// 라이트 · 다크 같은 모양(테두리 없는 유리 필). 다크는 바도 필도 어두운 유리라 필이 묻히므로
    /// 유리 자체에 옅은 흰 틴트만 더한다 — 칠한 바탕 · 테두리는 넣지 않는다.
    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear)
                .glassEffect(colorScheme == .dark ? .regular.tint(.white.opacity(0.12)).interactive() : .regular.interactive(),
                             in: Capsule())
        } else {
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 0.5))
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct DozyMainTabBarPreviewHost: View {
    @State private var selection: MainTab = .home
    @State private var isCompact = false
    @State private var lastAction: String = "—"
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [DozyColor.Brand.primary.opacity(0.25), DozyColor.Background.grouped],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: DozySpacing.lg) {
                Spacer()
                Text("Selected: \(selection.title)")
                    .font(DozyFont.headline)
                Text("Action: \(lastAction)")
                    .font(DozyFont.subheadline)
                    .foregroundStyle(DozyColor.Text.secondary)
                Toggle("Compact", isOn: $isCompact).padding(.horizontal, 40)
                Spacer()
            }
            DozyMainTabBar(selection: $selection,
                           isCompact: isCompact,
                           onReselect: { _ in lastAction = "reselect" },
                           onCreateEvent: { lastAction = "create event" })
                .padding(.bottom, DozyTabBarMetrics.bottomMargin)
        }
    }
}

#Preview("Light") {
    DozyMainTabBarPreviewHost().preferredColorScheme(.light)
}

#Preview("Dark") {
    DozyMainTabBarPreviewHost().preferredColorScheme(.dark)
}
#endif
