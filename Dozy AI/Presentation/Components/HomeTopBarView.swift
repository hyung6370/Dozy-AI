//
//  HomeTopBarView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import SwiftUI

struct HomeTopBarView: View {

    let hasNotification: Bool
    /// 로그아웃 상태에서는 공유 캘린더 진입 아이콘을 숨긴다.
    let isLoggedIn: Bool
    let onSharedCalendarTap: () -> Void
    let onNotificationTap: () -> Void
    let onProfileTap: () -> Void

    /// 토스 스타일 Pull-to-Refresh 의 당김 진행도 (0.0 ~ 1.0+).
    /// 부모가 ScrollView contentOffset 을 기반으로 실시간 계산해 주입한다.
    var pullProgress: Double = 0
    /// 새로고침 진행 중 여부. true 인 동안 내부 요소는 minScale 로 고정되고
    /// 회색 처리 상태가 유지된다. false 로 복귀할 때 spring 으로 탄성 복원.
    var isRefreshing: Bool = false

    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
    private var themeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var theme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: themeRaw) ?? .defaultTheme
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = String(localized: "M월 d일 EEEE")
        return formatter.string(from: Date())
    }

    @Environment(\.colorScheme) private var colorScheme

    /// 내부 요소가 축소될 수 있는 최소 비율. 값이 클수록 축소 폭이 작아진다.
    /// 0.85 → 최대 15% 축소, 절제된 미세 인터랙션.
    private static let minContentScale: CGFloat = 0.85

    /// 0...1 로 clamp 한 진행도. 표시용 계산은 모두 이 값을 사용한다.
    private var clampedProgress: Double {
        min(max(pullProgress, 0), 1)
    }

    /// 내부 요소(HStack) 의 현재 scale. 로딩 중이면 minScale 에 고정,
    /// 아니면 진행도에 따라 1.0 → minScale 로 선형 보간.
    private var contentScale: CGFloat {
        if isRefreshing { return Self.minContentScale }
        return 1.0 - (1.0 - Self.minContentScale) * CGFloat(clampedProgress)
    }

    /// 그레이스케일 강도. 0 = 원래 색, 1 = 완전 회색.
    /// 컬러 에셋 (앱 로고 등) 의 채도를 빼는 데 효과적.
    private var grayAmount: Double {
        if isRefreshing { return 1.0 }
        return clampedProgress
    }

    /// 페이드 강도. 1.0 = 원래 불투명, 0.45 = 흐림.
    /// 이미 모노톤인 텍스트/아이콘 에셋은 `.grayscale` 이 시각적 영향이 없어서
    /// 별도로 opacity 를 같이 깎아줘야 "회색 처리" 느낌이 일관되게 나타난다.
    private var fadeAmount: Double {
        if isRefreshing { return 0.45 }
        return 1.0 - 0.55 * clampedProgress
    }

    var body: some View {
        // 상단바 내부 요소들 — 이 HStack 전체가 함께 scale + grayscale 된다.
        // 배경 (.regularMaterial) 은 외부 .background 에 적용되어 틀은 그대로 유지된 채,
        // 오직 내부 콘텐츠만 비례 축소 + 회색 처리되는 효과.
        HStack {
            HStack(spacing: 8) {
                Image("Dozy-AI-20x20")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)

                Text(todayString)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            HStack(spacing: 16) {
                if isLoggedIn {
                    Button { onSharedCalendarTap() } label: {
                        Image(colorScheme == .dark ? "Dark-Home-Share-Calendar" : "Light-Home-Share-Calendar")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    }
                }

                Button { onNotificationTap() } label: {
                    Image(hasNotification
                        ? (colorScheme == .dark ? "Dark-Bell-on" : "Light-Bell-on")
                        : (colorScheme == .dark ? "Dark-Bell-non" : "Light-Bell-non")
                    )
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }

                Button { onProfileTap() } label: {
                    Image(colorScheme == .dark ? "Dark-User" : "Light-User")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
            }
        }
        .scaleEffect(contentScale, anchor: .center)
        .grayscale(grayAmount)
        .opacity(fadeAmount)
        // 당기는 동안에는 finger 와 1:1 (animation 없음).
        // isRefreshing 의 true/false 전환 순간에만 통통 튕기는 spring 적용 —
        // scale / grayscale / opacity 가 모두 한 번에 탄성 복귀.
        .animation(.spring(response: 0.55, dampingFraction: 0.45), value: isRefreshing)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // 배경을 상단 safe area (status bar 영역) 까지 확장 + blur material 처리 —
        // 콘텐츠가 위로 스크롤돼도 또렷이 비치지 않고 흐리게 가려진다. bar 의 콘텐츠
        // 위치는 safe area 안에 그대로 유지.
        .background(topBarBackground.ignoresSafeArea(edges: .top))
    }

    @ViewBuilder
    private var topBarBackground: some View {
        switch theme {
        case .system:
            // systemBackground tint + regularMaterial blur — 홈탭 콘텐츠 (systemBackground 위) 와
            // 톤은 일치하면서, 위로 스크롤되어 올라오는 콘텐츠가 옅게 비쳐 보인다.
            // tint 만으로는 불투명해져서 비침이 사라지고, material 만으론 톤이 살짝 어긋날 수
            // 있어 둘을 함께 깐다.
            DozyColor.Background.primary.opacity(0.35)
                .background(.regularMaterial)
        case .ambientMesh, .blob:
            // ambient / blob 테마는 콘텐츠 배경이 풍부해서 상단바를 blur 로 띄워야
            // 위쪽 status bar 영역과 콘텐츠 가독성을 함께 확보할 수 있다.
            Rectangle().fill(.regularMaterial)
        }
    }
}
