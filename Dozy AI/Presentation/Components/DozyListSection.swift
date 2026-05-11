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
    let header: String?
    let footer: String?
    @ViewBuilder var content: () -> Content

    init(header: String? = nil, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DozySpacing.xs) {
            if let header {
                Text(header)
                    .font(DozyFont.footnote)
                    .foregroundStyle(DozyColor.Text.secondary)
                    .padding(.horizontal, DozySpacing.md)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(DozyColor.Background.groupedRow)
            .clipShape(RoundedRectangle(cornerRadius: DozyRadius.md, style: .continuous))

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
/// - `showsDivider`: 마지막 행은 false 로 두어 아래 구분선이 안 보이게.
struct DozyListRow<Icon: View, Trailing: View>: View {
    let title: String
    let titleColor: Color
    let showsDivider: Bool
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        titleColor: Color = DozyColor.Text.primary,
        showsDivider: Bool = true,
        @ViewBuilder icon: @escaping () -> Icon = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.titleColor = titleColor
        self.showsDivider = showsDivider
        self.icon = icon
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DozySpacing.sm) {
                icon()
                Text(title)
                    .font(DozyFont.body)
                    .foregroundStyle(titleColor)
                Spacer(minLength: DozySpacing.sm)
                trailing()
            }
            .padding(.horizontal, DozySpacing.md)
            .padding(.vertical, DozySpacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())

            if showsDivider {
                Divider()
                    .padding(.leading, DozySpacing.md)
            }
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
