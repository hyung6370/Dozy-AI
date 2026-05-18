//
//  DozyTokensCatalog.swift
//  Dozy AI
//
//  토큰을 Xcode Preview 에서 한눈에 검증하기 위한 카탈로그.
//  배포 빌드에는 영향 없음 (DEBUG 만 빌드되도록 둘러도 좋음).
//

import SwiftUI

#if DEBUG

private struct DozyTokensCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DozySpacing.xl) {
                colors
                fonts
                spacing
                radii
            }
            .padding(DozySpacing.md)
        }
        .background(DozyColor.Background.grouped)
    }

    private var colors: some View {
        section("Colors") {
            VStack(alignment: .leading, spacing: DozySpacing.xs) {
                colorRow("Background.primary", DozyColor.Background.primary)
                colorRow("Background.grouped", DozyColor.Background.grouped)
                colorRow("Background.groupedRow", DozyColor.Background.groupedRow)
                colorRow("Surface.primary", DozyColor.Surface.primary)
                colorRow("Surface.elevated", DozyColor.Surface.elevated)
                Divider()
                colorRow("Brand.primary", DozyColor.Brand.primary)
                colorRow("Brand.secondary", DozyColor.Brand.secondary)
                Divider()
                colorRow("State.success", DozyColor.State.success)
                colorRow("State.warning", DozyColor.State.warning)
                colorRow("State.danger", DozyColor.State.danger)
                colorRow("State.info", DozyColor.State.info)
                Divider()
                colorRow("Separator", DozyColor.separator)
            }
        }
    }

    private var fonts: some View {
        section("Fonts") {
            VStack(alignment: .leading, spacing: DozySpacing.xs) {
                fontRow("largeTitle", DozyFont.largeTitle)
                fontRow("title", DozyFont.title)
                fontRow("title2", DozyFont.title2)
                fontRow("title3", DozyFont.title3)
                fontRow("headline", DozyFont.headline)
                fontRow("body", DozyFont.body)
                fontRow("bodyEmphasized", DozyFont.bodyEmphasized)
                fontRow("subheadline", DozyFont.subheadline)
                fontRow("callout", DozyFont.callout)
                fontRow("footnote", DozyFont.footnote)
                fontRow("caption", DozyFont.caption)
                fontRow("caption2", DozyFont.caption2)
                fontRow("bodyMono", DozyFont.bodyMono)
            }
        }
    }

    private var spacing: some View {
        section("Spacing") {
            VStack(alignment: .leading, spacing: DozySpacing.xs) {
                spacingRow("xxxs", DozySpacing.xxxs)
                spacingRow("xxs", DozySpacing.xxs)
                spacingRow("xs", DozySpacing.xs)
                spacingRow("sm", DozySpacing.sm)
                spacingRow("md", DozySpacing.md)
                spacingRow("lg", DozySpacing.lg)
                spacingRow("xl", DozySpacing.xl)
                spacingRow("xxl", DozySpacing.xxl)
                spacingRow("xxxl", DozySpacing.xxxl)
                spacingRow("xxxxl", DozySpacing.xxxxl)
            }
        }
    }

    private var radii: some View {
        section("Radius") {
            VStack(alignment: .leading, spacing: DozySpacing.xs) {
                radiusRow("xs", DozyRadius.xs)
                radiusRow("sm", DozyRadius.sm)
                radiusRow("md", DozyRadius.md)
                radiusRow("lg", DozyRadius.lg)
                radiusRow("xl", DozyRadius.xl)
                radiusRow("pill", 32)
            }
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DozySpacing.sm) {
            Text(title)
                .font(DozyFont.title3)
                .foregroundStyle(DozyColor.Text.primary)
            content()
                .padding(DozySpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DozyColor.Background.groupedRow)
                .clipShape(RoundedRectangle(cornerRadius: DozyRadius.md, style: .continuous))
        }
    }

    private func colorRow(_ name: String, _ color: Color) -> some View {
        HStack(spacing: DozySpacing.sm) {
            RoundedRectangle(cornerRadius: DozyRadius.sm, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: DozyRadius.sm, style: .continuous)
                        .strokeBorder(DozyColor.separator, lineWidth: 0.5)
                )
                .frame(width: 36, height: 24)
            Text(name)
                .font(DozyFont.subheadline)
                .foregroundStyle(DozyColor.Text.primary)
        }
    }

    private func fontRow(_ name: String, _ font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DozySpacing.sm) {
            Text(name)
                .font(DozyFont.captionMono)
                .foregroundStyle(DozyColor.Text.secondary)
                .frame(width: 120, alignment: .leading)
            Text("Dozy AI 디자인 토큰 0123")
                .font(font)
                .foregroundStyle(DozyColor.Text.primary)
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: DozySpacing.sm) {
            Text(name)
                .font(DozyFont.captionMono)
                .foregroundStyle(DozyColor.Text.secondary)
                .frame(width: 60, alignment: .leading)
            Text("\(Int(value))")
                .font(DozyFont.captionMono)
                .foregroundStyle(DozyColor.Text.tertiary)
                .frame(width: 30, alignment: .leading)
            Rectangle()
                .fill(DozyColor.Brand.primary)
                .frame(width: value, height: 12)
        }
    }

    private func radiusRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: DozySpacing.sm) {
            Text(name)
                .font(DozyFont.captionMono)
                .foregroundStyle(DozyColor.Text.secondary)
                .frame(width: 60, alignment: .leading)
            RoundedRectangle(cornerRadius: value, style: .continuous)
                .fill(DozyColor.Brand.primary.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: value, style: .continuous)
                        .strokeBorder(DozyColor.Brand.primary, lineWidth: 1)
                )
                .frame(width: 64, height: 64)
            Text("\(Int(value))")
                .font(DozyFont.captionMono)
                .foregroundStyle(DozyColor.Text.tertiary)
        }
    }
}

#Preview("Light") {
    DozyTokensCatalog()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DozyTokensCatalog()
        .preferredColorScheme(.dark)
}

#endif
