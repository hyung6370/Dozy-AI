//
//  DozyTabBarChrome.swift
//  Dozy AI
//
//  하단 탭바 크롬 상태 + 탭 루트 스크롤뷰가 그 상태를 구동하는 모디파이어.
//  - 위로 쓸면(오프셋 증가) 탭바가 축소(라벨 접힘·알약 좁아짐), 아래로 쓸면 복원.
//  - 이미 선택된 탭을 다시 누르면 그 탭의 루트 스크롤뷰가 맨 위로 올라가고 크롬이 펼쳐진다.
//  - 탭 루트가 화면에서 사라지면(하위 화면 push, 전체 화면 커버) 탭바를 숨기고, 돌아오면 다시 띄운다.
//  MainTabView 가 `DozyTabBarChrome` 을 소유해 환경으로 내려주고, 각 탭 루트는 `.environment(\.dozyTab, …)` 로
//  자기 탭을 받은 뒤 루트 ScrollView 에 `.drivesTabBarChrome()` 을 건다.
//  스크롤 지오메트리/위상 API 는 iOS 18+ 라 17 에서는 무동작(탭바는 항상 펼친 상태).
//

import SwiftUI

@Observable
@MainActor
final class DozyTabBarChrome {
    private(set) var isCompact = false
    /// 탭별 '맨 위로' 요청 카운터 — 루트 스크롤뷰(drivesTabBarChrome)가 변화를 보고 맨 위로 스크롤한다.
    private(set) var scrollToTopTicks: [MainTab: Int] = [:]

    func setCompact(_ compact: Bool) {
        guard isCompact != compact else { return }
        isCompact = compact
    }

    func reset() { isCompact = false }

    /// 탭별 루트 화면 표시 여부. 루트가 onDisappear(= 하위 화면 push / 전체 화면 커버)면 false.
    /// 아직 보고가 없는 탭은 루트로 간주한다(콜드 스타트에 바가 깜빡이지 않게).
    private(set) var rootVisible: [MainTab: Bool] = [:]

    func setRootVisible(_ visible: Bool, for tab: MainTab) {
        guard rootVisible[tab] != visible else { return }
        rootVisible[tab] = visible
    }

    func isAtRoot(_ tab: MainTab) -> Bool { rootVisible[tab] ?? true }

    /// 탭별 "커스텀 오버레이(같은 뷰 계층에 그린 시트 등)가 떠 있음" 플래그. `hidesTabBar(_:)` 가 보고한다.
    private(set) var overlayShown: [MainTab: Bool] = [:]

    func setOverlayShown(_ shown: Bool, for tab: MainTab) {
        guard overlayShown[tab] != shown else { return }
        overlayShown[tab] = shown
    }

    /// 이 탭에서 바를 보여도 되는지 — 루트 화면이고 커스텀 오버레이가 없을 때.
    func showsBar(for tab: MainTab) -> Bool {
        isAtRoot(tab) && !(overlayShown[tab] ?? false)
    }

    /// 이미 선택된 탭 재터치 → 해당 탭 루트를 맨 위로.
    func reselect(_ tab: MainTab) {
        scrollToTopTicks[tab, default: 0] += 1
    }
}

// MARK: - Environment

private struct DozyTabKey: EnvironmentKey { static let defaultValue: MainTab? = nil }

extension EnvironmentValues {
    /// 이 뷰가 속한 메인 탭 — MainTabView 가 내려주고, 루트 스크롤뷰가 '맨 위로' 요청을 자기 탭 것만 듣는 데 쓴다.
    var dozyTab: MainTab? {
        get { self[DozyTabKey.self] }
        set { self[DozyTabKey.self] = newValue }
    }
}

// MARK: - Modifier

extension View {
    /// 탭 루트 콘텐츠(NavigationStack 바로 안쪽)에 건다 — 루트가 화면에 있는지 크롬에 보고한다.
    /// NavigationStack 은 하위 화면을 push 하면 루트에 onDisappear, pop 하면 onAppear 를 보내므로
    /// 이것만으로 "하위 화면에 들어갔는지" 를 알 수 있다. 탭 전환으로 사라지는 경우도 같은 신호지만
    /// 바는 "현재 선택 탭의 루트" 만 보므로 영향이 없다.
    func tracksTabRoot() -> some View {
        modifier(DozyTabRootTracker())
    }

    /// 시스템 `.sheet` 가 아니라 같은 뷰 계층에 직접 그리는 커스텀 시트/오버레이(설정의 AuthSheetView 등)를 띄울 때
    /// `hidden` 에 그 표시 상태를 넘긴다 — true 인 동안 탭바가 내려가 있고, false 로 돌아오면 다시 올라온다.
    /// 시스템 시트는 창 전체를 덮어 바가 가려지므로 이 모디파이어가 필요 없다.
    func hidesTabBar(_ hidden: Bool) -> some View {
        modifier(DozyTabBarHider(hidden: hidden))
    }

    /// 탭 루트의 ScrollView 에 건다 — ① 스크롤 방향을 탭바 크롬에 보고(위로 쓸기 = 축소 / 아래로 쓸기 = 복원)
    /// ② 선택된 탭 재터치 시 맨 위로 스크롤. 환경에 크롬/탭이 없으면(프리뷰) 무동작.
    func drivesTabBarChrome() -> some View {
        modifier(DozyTabBarChromeScrollSource())
    }
}

private struct DozyTabBarHider: ViewModifier {
    let hidden: Bool
    @Environment(DozyTabBarChrome.self) private var chrome: DozyTabBarChrome?
    @Environment(\.dozyTab) private var tab

    func body(content: Content) -> some View {
        content.onChange(of: hidden, initial: true) { _, hidden in
            if let tab { chrome?.setOverlayShown(hidden, for: tab) }
        }
    }
}

private struct DozyTabRootTracker: ViewModifier {
    @Environment(DozyTabBarChrome.self) private var chrome: DozyTabBarChrome?
    @Environment(\.dozyTab) private var tab

    func body(content: Content) -> some View {
        content
            .onAppear { if let tab { chrome?.setRootVisible(true, for: tab) } }
            .onDisappear { if let tab { chrome?.setRootVisible(false, for: tab) } }
    }
}

private struct DozyTabBarChromeScrollSource: ViewModifier {
    @Environment(DozyTabBarChrome.self) private var chrome: DozyTabBarChrome?
    /// 직전 오프셋(제스처 단위로 리셋). nil 이면 다음 샘플은 기준점만 잡는다.
    @State private var lastOffset: CGFloat?
    /// 손가락이 닿아 있는지(tracking·interacting).
    @State private var isTouching = false
    /// 마지막으로 손가락이 만든 방향(+1 위로 쓸기 = 오프셋 증가, -1 아래로 쓸기). 손을 뗀 뒤 관성은 이 방향일 때만 인정한다.
    @State private var touchDirection: CGFloat = 0

    /// 방향 판정 최소 이동량(pt) — 미세 떨림 무시.
    private static let threshold: CGFloat = 4

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .modifier(DozyScrollToTopOnReselect())
                // 콘텐츠가 화면보다 짧아도 세로 바운스를 켜 둔다 — 그래야 짧은 화면에서도 손가락 방향이 오프셋 변화로 잡힌다.
                .scrollBounceBehavior(.always, axes: .vertical)
                .onScrollPhaseChange { _, newPhase in
                    isTouching = newPhase == .tracking || newPhase == .interacting
                    if newPhase == .idle { lastOffset = nil }   // 다음 제스처는 새 기준점에서
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                    guard let previous = lastOffset else { lastOffset = offset; return }
                    let delta = offset - previous
                    guard abs(delta) >= Self.threshold else { return }
                    lastOffset = offset
                    let direction: CGFloat = delta > 0 ? 1 : -1
                    if isTouching {
                        touchDirection = direction
                    } else {
                        // 손을 뗀 뒤: 같은 방향의 관성(플링)만 인정. 반대 방향은 러버밴드 복귀(바운스)이므로 무시 —
                        // 짧은 화면에서 위로 쓸고 놓았을 때 축소가 바로 풀리거나, 끝에서 튕길 때 거꾸로 접히는 것을 막는다.
                        guard direction == touchDirection else { return }
                    }
                    chrome?.setCompact(direction > 0)   // 위로 쓸기(오프셋 증가) = 축소, 아래로 쓸기 = 복원
                }
        } else {
            content   // iOS 17: ScrollPosition·스크롤 위상 API 미지원 — 축소/맨 위로 생략
        }
    }
}

/// 자기 탭의 '맨 위로' 틱(`DozyTabBarChrome.scrollToTopTicks`)이 바뀌면 맨 위로 스크롤하고 크롬을 편다.
/// 프로그램 스크롤은 손가락이 없어 방향 판정(마지막 터치 방향 관성만 인정)에 걸러지므로 `chrome.reset()` 을 명시적으로 부른다.
@available(iOS 18.0, *)
private struct DozyScrollToTopOnReselect: ViewModifier {
    @Environment(DozyTabBarChrome.self) private var chrome: DozyTabBarChrome?
    @Environment(\.dozyTab) private var tab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onChange(of: tab.flatMap { chrome?.scrollToTopTicks[$0] }) { _, _ in
                if reduceMotion {
                    position.scrollTo(edge: .top)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { position.scrollTo(edge: .top) }
                }
                chrome?.reset()
            }
    }
}
