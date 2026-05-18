//
//  BackgroundThemePickerView.swift
//  Dozy AI
//
//  앱 ambient 배경 테마 선택 화면.
//  AppStorage("iosBackgroundTheme") 값을 변경하면 RootView 가 즉시 반영한다.
//

import SwiftUI

struct BackgroundThemePickerView: View {

    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
    private var themeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var currentTheme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: themeRaw) ?? .defaultTheme
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DozySpacing.md) {
                ForEach(DozyBackgroundTheme.allCases) { theme in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            themeRaw = theme.rawValue
                        }
                    } label: {
                        themeCard(for: theme, isSelected: theme == currentTheme)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DozySpacing.md)
            .padding(.vertical, DozySpacing.lg)
        }
        .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
        .navigationTitle("테마")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Card

    private func themeCard(for theme: DozyBackgroundTheme, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: DozySpacing.sm) {
            // Preview
            themePreview(for: theme)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DozyRadius.md, style: .continuous))

            // Title + checkmark
            HStack(alignment: .firstTextBaseline, spacing: DozySpacing.xs) {
                VStack(alignment: .leading, spacing: DozySpacing.xxxs) {
                    Text(theme.displayName)
                        .font(DozyFont.bodyEmphasized)
                        .foregroundStyle(DozyColor.Text.primary)
                    Text(theme.summary)
                        .font(DozyFont.footnote)
                        .foregroundStyle(DozyColor.Text.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: DozySpacing.sm)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DozyColor.Brand.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(DozySpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DozyRadius.lg, style: .continuous)
                .fill(DozyColor.Background.groupedRow)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DozyRadius.lg, style: .continuous)
                .strokeBorder(
                    isSelected ? DozyColor.Brand.primary : Color.clear,
                    lineWidth: 2
                )
        )
    }

    @ViewBuilder
    private func themePreview(for theme: DozyBackgroundTheme) -> some View {
        switch theme {
        case .system:
            ZStack {
                DozyColor.Background.primary
                Text("기본")
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
            }
        case .ambientMesh:
            AmbientMeshBackgroundView(intensity: 1.0)
                .allowsHitTesting(false)
        case .blob:
            BlobBackgroundView(intensity: 0.6)
                .allowsHitTesting(false)
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        BackgroundThemePickerView()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        BackgroundThemePickerView()
    }
    .preferredColorScheme(.dark)
}
#endif
