//
//  MacThemePaletteTests.swift
//  Dozy AI (macOS)Tests
//
//  macOS 테마 팔레트(#107)의 토큰 규칙을 고정한다. 기본 테마는 네이티브 룩(시스템 텍스트 · 투명 채움)을
//  유지해야 하고, Ambient/Blob 은 서로 · 라이트/다크 간에 강조색 · 본문 · 카드 색이 달라야 한다.
//

import Testing
import SwiftUI
@testable import Dozy_AI

@Suite("MacThemePalette")
@MainActor
struct MacThemePaletteTests {

    private let schemes: [ColorScheme] = [.light, .dark]

    @Test("기본 테마는 isSystem — 시스템 텍스트 색 · 투명 카드 채움 · 그림자 없음", arguments: [ColorScheme.light, .dark])
    func systemKeepsNativeLook(scheme: ColorScheme) {
        let p = MacBackgroundTheme.system.palette(for: scheme)
        #expect(p.isSystem)
        #expect(p.textPrimary == .primary)
        #expect(p.sectionTitle == .secondary)
        #expect(p.cardFill == .clear)
        #expect(p.cardShadow == .clear)
        #expect(p.accent == DozyColor.Brand.primary)
    }

    @Test("Ambient · Blob 은 isSystem 이 아니고 섹션 제목이 강조색", arguments: [MacBackgroundTheme.ambientMesh, .blob])
    func themedPalettesUseAccentTitles(theme: MacBackgroundTheme) {
        for scheme in schemes {
            let p = theme.palette(for: scheme)
            #expect(!p.isSystem)
            #expect(p.sectionTitle == p.accent)
            #expect(p.cardFill != .clear)
            #expect(p.cardShadow != .clear)
        }
    }

    @Test("Ambient 와 Blob 은 강조색 · 본문 · 카드 색이 서로 다르다", arguments: [ColorScheme.light, .dark])
    func ambientAndBlobDiffer(scheme: ColorScheme) {
        let a = MacBackgroundTheme.ambientMesh.palette(for: scheme)
        let b = MacBackgroundTheme.blob.palette(for: scheme)
        #expect(a.accent != b.accent)
        #expect(a.textPrimary != b.textPrimary)
        #expect(a.cardFill != b.cardFill)
    }

    @Test("라이트와 다크는 강조색 · 본문 · 카드 색이 다르다", arguments: [MacBackgroundTheme.ambientMesh, .blob])
    func lightAndDarkDiffer(theme: MacBackgroundTheme) {
        let light = theme.palette(for: .light)
        let dark = theme.palette(for: .dark)
        #expect(light.accent != dark.accent)
        #expect(light.textPrimary != dark.textPrimary)
        #expect(light.cardFill != dark.cardFill)
    }

    @Test("accentSoft · accentStroke 는 강조색에서 파생된다")
    func derivedAccents() {
        for theme in MacBackgroundTheme.allCases {
            for scheme in schemes {
                let p = theme.palette(for: scheme)
                #expect(p.accentSoft == p.accent.opacity(0.12))
                #expect(p.accentStroke == p.accent.opacity(0.18))
            }
        }
    }

    @Test("palette(for:) 는 테마별 정적 팔레트와 같다")
    func mappingMatchesStaticFactories() {
        #expect(MacBackgroundTheme.system.palette(for: .light) == .system(.light))
        #expect(MacBackgroundTheme.ambientMesh.palette(for: .dark) == .ambient(.dark))
        #expect(MacBackgroundTheme.blob.palette(for: .light) == .blob(.light))
    }

    @Test("기본값은 Ambient, 표시 이름과 설명이 비어 있지 않다")
    func defaultsAndLabels() {
        #expect(MacBackgroundTheme.defaultTheme == .ambientMesh)
        for theme in MacBackgroundTheme.allCases {
            #expect(!theme.displayName.isEmpty)
            #expect(!theme.summary.isEmpty)
            #expect(MacBackgroundTheme(rawValue: theme.id) == theme)
        }
    }
}
