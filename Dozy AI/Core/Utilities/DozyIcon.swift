//
//  DozyIcon.swift
//  Dozy AI
//
//  앱 아이콘을 SF Symbol 대신 Iconsax(outline · bold) 커스텀 심볼로 그린다.
//  `DozyIcons.xcassets` 의 .symbolset 은 SF Symbols 템플릿(2.0)으로 감싼 Iconsax SVG 라서
//  `Image(systemName:)` 과 똑같이 폰트 크기·weight·foregroundStyle 을 따른다.
//
//  호출부는 `Image(symbol:)` · `Label(_:symbol:)` 만 쓴다. 매핑이 없는 이름(apple.logo, pin, 글자 원형 등)은
//  SF Symbol 로 그대로 떨어지므로 새 아이콘은 SF 이름으로 먼저 쓰고, 필요하면 아래 표와 심볼셋에 추가한다.
//  하단 탭바(DozyMainTabBar)는 의도적으로 SF Symbol 을 유지한다.
//

import SwiftUI

enum DozyIcon {
    /// Iconsax 심볼셋이 있는 SF Symbol 이름. 심볼셋 이름은 `ix-` + 점을 `-` 로 바꾼 것.
    static let customNames: Set<String> = [
        "arrow.clockwise",
        "arrow.counterclockwise",
        "arrow.down",
        "arrow.down.app.fill",
        "arrow.down.right",
        "arrow.down.right.circle",
        "arrow.down.right.circle.fill",
        "arrow.left",
        "arrow.left.arrow.right",
        "arrow.right",
        "arrow.right.circle",
        "arrow.triangle.2.circlepath",
        "arrow.trianglehead.clockwise",
        "arrow.up",
        "arrow.up.forward.app.fill",
        "arrow.up.right",
        "arrow.up.right.circle.fill",
        "arrow.uturn.backward",
        "arrow.uturn.left",
        "bell",
        "bell.badge",
        "bell.badge.fill",
        "bell.fill",
        "bell.slash",
        "brain.head.profile",
        "calendar",
        "calendar.badge.checkmark",
        "calendar.badge.clock",
        "calendar.badge.exclamationmark",
        "calendar.badge.minus",
        "calendar.badge.plus",
        "calendar.circle",
        "chart.bar",
        "chart.bar.fill",
        "chart.bar.xaxis",
        "chart.line.downtrend.xyaxis",
        "chart.line.uptrend.xyaxis",
        "chart.pie",
        "chart.pie.fill",
        "checklist",
        "checkmark",
        "checkmark.circle",
        "checkmark.circle.fill",
        "checkmark.seal.fill",
        "chevron.down",
        "chevron.left",
        "chevron.right",
        "chevron.up",
        "chevron.up.chevron.down",
        "circle",
        "circle.fill",
        "clock",
        "clock.badge.exclamationmark",
        "clock.fill",
        "crop",
        "crown.fill",
        "cursorarrow.click.2",
        "doc.on.doc",
        "doc.text",
        "doc.text.fill",
        "ellipsis",
        "envelope",
        "envelope.fill",
        "exclamationmark.circle",
        "exclamationmark.triangle.fill",
        "flag.checkered",
        "flag.fill",
        "flame",
        "flame.fill",
        "hand.tap",
        "humidity.fill",
        "info.circle",
        "key.fill",
        "line.3.horizontal.decrease",
        "list.bullet",
        "lock.shield",
        "location.fill",
        "lock",
        "lock.rotation",
        "lock.shield.fill",
        "macwindow",
        "magnifyingglass",
        "mappin",
        "mappin.and.ellipse",
        "menubar.rectangle",
        "mic.fill",
        "minus.magnifyingglass",
        "note.text",
        "number",
        "paintpalette.fill",
        "pencil",
        "pencil.line",
        "person.2",
        "person.2.badge.plus",
        "person.2.fill",
        "person.2.slash",
        "person",
        "person.crop.circle.badge.xmark",
        "person.badge.plus",
        "person.crop.circle.badge.questionmark",
        "person.fill",
        "platter.filled.top.iphone",
        "plus",
        "plus.circle",
        "plus.circle.fill",
        "plus.magnifyingglass",
        "questionmark.circle",
        "rectangle.3.group",
        "rectangle.on.rectangle.angled",
        "rectangle.portrait.and.arrow.right",
        "repeat",
        "rotate.left",
        "rotate.right",
        "scope",
        "sidebar.left",
        "sparkles",
        "square.grid.2x2",
        "square.and.arrow.up",
        "square.and.pencil",
        "star",
        "star.fill",
        "stop.fill",
        "sun.max.fill",
        "tag",
        "trash",
        "trash.fill",
        "tray",
        "wifi.slash",
        "xmark.circle.fill"
    ]

    /// SF 이름에 대응하는 커스텀 심볼셋 이름. 없으면 nil.
    static func assetName(for systemName: String) -> String? {
        guard customNames.contains(systemName) else { return nil }
        return "ix-" + systemName.replacingOccurrences(of: ".", with: "-")
    }
}

extension Image {
    /// `Image(systemName:)` 대체. 매핑된 이름은 Iconsax 심볼, 나머지는 SF Symbol.
    init(symbol systemName: String) {
        if let name = DozyIcon.assetName(for: systemName) {
            self.init(name)
        } else {
            self.init(systemName: systemName)
        }
    }
}

extension Label where Title == Text, Icon == Image {
    /// `Label(_:systemImage:)` 대체.
    init(_ titleKey: LocalizedStringKey, symbol systemName: String) {
        self.init { Text(titleKey) } icon: { Image(symbol: systemName) }
    }

    @_disfavoredOverload
    init<S: StringProtocol>(_ title: S, symbol systemName: String) {
        self.init { Text(title) } icon: { Image(symbol: systemName) }
    }
}
