//
//  DozyListSection.swift
//  Dozy AI
//
//  v2.0.0 커스텀 리스트 섹션 / 행 컴포넌트.
//  - SwiftUI 의 Form/Section/List 를 ScrollView + VStack 기반으로 교체할 때 사용.
//  - 디자인 토큰 기반.
//

import SwiftUI

// MARK: - DozyListSection

struct DozyListSection<Content: View>: View {
    /// header / footer 는 `LocalizedStringKey` — 호출부의 문자열 리터럴이 String Catalog
    /// 자동 추출 대상이 되려면 SwiftUI `Text(_:LocalizedStringKey)` 경로를 타야 한다.
    let header: LocalizedStringKey?
    let footer: LocalizedStringKey?
    @ViewBuilder var content: () -> Content

    init(header: LocalizedStringKey? = nil, footer: LocalizedStringKey? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DozySpacing.sm) {
            if let header {
                Text(header)
                    .font(DozyFont.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(DozyColor.Text.secondary)
                    .padding(.horizontal, DozySpacing.md)
            }

            VStack(spacing: 0) {
                content()
            }
            .clipShape(RoundedRectangle(cornerRadius: DozyRadius.lg, style: .continuous))
            .dozyThemedCardSurface(cornerRadius: DozyRadius.lg)

            if let footer {
                Text(footer)
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
                    .padding(.horizontal, DozySpacing.md)
                    .padding(.top, DozySpacing.xxxs)
            }
        }
        .padding(.horizontal, DozySpacing.md)
    }
}

// MARK: - DozyListRow

/// 단일 리스트 행. 외부에서 NavigationLink / Button 으로 감싸서 tap 처리.
/// 카드 안 row 사이엔 divider 가 없고 spacing 만으로 분리 (파스텔 컴팩트 톤).
struct DozyListRow<Icon: View, Trailing: View>: View {
    /// title 은 `LocalizedStringKey` — String Catalog 자동 추출 보장.
    let title: LocalizedStringKey
    let titleColor: Color
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: LocalizedStringKey,
        titleColor: Color = DozyColor.Text.primary,
        showsDivider _: Bool = true,  // 호환: 호출부 인자 유지, 내부적으론 사용 안 함
        @ViewBuilder icon: @escaping () -> Icon = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.titleColor = titleColor
        self.icon = icon
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: DozySpacing.md) {
            icon()
            Text(title)
                .font(DozyFont.bodyEmphasized)
                .foregroundStyle(titleColor)
            Spacer(minLength: DozySpacing.sm)
            trailing()
        }
        .padding(.horizontal, DozySpacing.md)
        .padding(.vertical, DozySpacing.md)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// Brand color 가 칠해진 원 안에 system icon. row 의 icon 으로 사용.
struct DozyTintedIcon: View {
    let systemName: String?
    let imageName: String?
    let tint: Color

    init(systemName: String, tint: Color = DozyColor.Brand.primary) {
        self.systemName = systemName
        self.imageName = nil
        self.tint = tint
    }

    init(imageName: String, tint: Color = DozyColor.Brand.primary) {
        self.systemName = nil
        self.imageName = imageName
        self.tint = tint
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 32, height: 32)
            iconView
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let systemName {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
        } else if let imageName {
            Image(imageName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }
}

// MARK: - Accessory helpers

/// 우측 chevron — NavigationLink/Button 행에 표준으로.
struct DozyChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DozyColor.Text.tertiary)
    }
}

/// 우측 값 표시 — "버전" 같은 read-only row 에 사용.
struct DozyTrailingValue: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DozyFont.subheadline)
            .foregroundStyle(DozyColor.Text.secondary)
    }
}

// MARK: - Preview

#if DEBUG
private struct DozyListPreviewHost: View {
    @State private var toggle = true
    var body: some View {
        ScrollView {
            VStack(spacing: DozySpacing.xl) {
                DozyListSection(header: "캘린더", footer: nil) {
                    DozyListRow(title: "캘린더 연동") {
                        Image(systemName: "calendar")
                            .foregroundStyle(DozyColor.Brand.primary)
                            .frame(width: 24)
                    } trailing: {
                        DozyChevron()
                    }
                    DozyListRow(title: "공유 캘린더", showsDivider: false) {
                        Image(systemName: "person.2")
                            .foregroundStyle(DozyColor.Brand.primary)
                            .frame(width: 24)
                    } trailing: {
                        DozyChevron()
                    }
                }

                DozyListSection(header: "앱 정보") {
                    DozyListRow(title: "개인정보 처리방침") {
                        Image(systemName: "hand.raised")
                            .foregroundStyle(DozyColor.Brand.primary)
                            .frame(width: 24)
                    } trailing: {
                        DozyChevron()
                    }
                    DozyListRow(title: "버전", showsDivider: false) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(DozyColor.Brand.primary)
                            .frame(width: 24)
                    } trailing: {
                        DozyTrailingValue(text: "2.0.0")
                    }
                }

                DozyListSection(footer: "탈퇴 시 모든 데이터가 영구 삭제됩니다.") {
                    DozyListRow(
                        title: "계정 탈퇴",
                        titleColor: DozyColor.State.danger,
                        showsDivider: false
                    ) {
                        Image(systemName: "trash")
                            .foregroundStyle(DozyColor.State.danger)
                            .frame(width: 24)
                    }
                }
            }
            .padding(.vertical, DozySpacing.lg)
        }
        .background(DozyColor.Background.grouped)
    }
}

#Preview("Light") {
    DozyListPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DozyListPreviewHost()
        .preferredColorScheme(.dark)
}
#endif
