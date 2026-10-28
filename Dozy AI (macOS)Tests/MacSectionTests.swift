//
//  MacSectionTests.swift
//  Dozy AI (macOS)Tests
//
//  사이드바 섹션(MacSection)의 에셋 이름 규칙과 순서를 고정한다. 에셋 이름은 iOS 와 공유하는
//  "Light|Dark-<Stem>[-selected]" 형식이라 오타가 나면 아이콘이 조용히 사라진다.
//

import Testing
import SwiftUI
@testable import Dozy_AI

@Suite("MacSection")
@MainActor
struct MacSectionTests {

    @Test("사이드바 순서는 오늘 · 캘린더 · 인사이트 · 설정")
    func order() {
        #expect(MacSection.allCases == [.today, .calendar, .insights, .settings])
        #expect(MacSection.allCases.map(\.displayName) == ["오늘", "캘린더", "인사이트", "설정"])
    }

    @Test("에셋 이름은 Light|Dark-<Stem>[-selected]")
    func assetNames() {
        #expect(MacSection.today.assetName(isSelected: false, colorScheme: .light) == "Light-House")
        #expect(MacSection.today.assetName(isSelected: true, colorScheme: .light) == "Light-House-selected")
        #expect(MacSection.calendar.assetName(isSelected: false, colorScheme: .dark) == "Dark-Calendar")
        #expect(MacSection.insights.assetName(isSelected: true, colorScheme: .dark) == "Dark-Insight-selected")
        #expect(MacSection.settings.assetName(isSelected: false, colorScheme: .light) == "Light-Setting")
    }

    @Test("id 는 rawValue 와 같고 왕복된다")
    func identity() {
        for section in MacSection.allCases {
            #expect(section.id == section.rawValue)
            #expect(MacSection(rawValue: section.id) == section)
        }
    }
}
