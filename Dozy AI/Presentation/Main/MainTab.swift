//
//  MainTab.swift
//  Dozy AI
//
//  메인 탭바의 탭 모델.
//  - rawValue 는 기존 selectedTab(Int) 와 호환되도록 유지한다.
//  - iconName(colorScheme:isSelected:) 는 Assets 의 {Light|Dark}-{Name}[-selected] 규칙을 따른다.
//

import SwiftUI

enum MainTab: Int, CaseIterable, Hashable, Identifiable {
    case home = 0
    case calendar = 1
    case insight = 2
    case settings = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home:     return "홈"
        case .calendar: return "캘린더"
        case .insight:  return "인사이트"
        case .settings: return "설정"
        }
    }

    /// 접근성 라벨. title 과 동일하지만, 향후 분리가 필요할 때를 위해 분리해 둔다.
    var accessibilityLabel: String { title }

    func iconName(colorScheme: ColorScheme, isSelected: Bool) -> String {
        let prefix = colorScheme == .dark ? "Dark" : "Light"
        let base: String
        switch self {
        case .home:     base = "House"
        case .calendar: base = "Calendar"
        case .insight:  base = "Insight"
        case .settings: base = "Setting"
        }
        return isSelected ? "\(prefix)-\(base)-selected" : "\(prefix)-\(base)"
    }
}
