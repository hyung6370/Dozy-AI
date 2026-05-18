//
//  DozyColor.swift
//  Dozy AI
//
//  시맨틱 컬러 토큰. iOS/macOS 공통.
//  - 시스템 컬러를 우선 매핑해 다크모드/접근성/하이콘트라스트를 무료로 얻는다.
//  - 브랜드 컬러는 hex 로 명시한다.
//

import SwiftUI

enum DozyColor {

    // MARK: - Background

    enum Background {
        /// 최하단 배경. iOS systemBackground / macOS windowBackground.
        static var primary: Color {
            #if os(iOS)
            Color(.systemBackground)
            #else
            Color(nsColor: .windowBackgroundColor)
            #endif
        }

        /// 그룹 배경. iOS systemGroupedBackground / macOS underPageBackground.
        static var grouped: Color {
            #if os(iOS)
            Color(.systemGroupedBackground)
            #else
            Color(nsColor: .underPageBackgroundColor)
            #endif
        }

        /// 그룹 안의 행 배경. iOS secondarySystemGroupedBackground / macOS controlBackground.
        static var groupedRow: Color {
            #if os(iOS)
            Color(.secondarySystemGroupedBackground)
            #else
            Color(nsColor: .controlBackgroundColor)
            #endif
        }
    }

    // MARK: - Surface

    enum Surface {
        /// 카드/패널 표면.
        static var primary: Color {
            #if os(iOS)
            Color(.secondarySystemBackground)
            #else
            Color(nsColor: .controlBackgroundColor)
            #endif
        }

        /// 한 단계 더 들어간 표면(중첩 카드).
        static var elevated: Color {
            #if os(iOS)
            Color(.tertiarySystemBackground)
            #else
            Color(nsColor: .underPageBackgroundColor)
            #endif
        }
    }

    // MARK: - Text

    enum Text {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let tertiary: Color = {
            #if os(iOS)
            Color(.tertiaryLabel)
            #else
            Color(nsColor: .tertiaryLabelColor)
            #endif
        }()
        static let placeholder: Color = {
            #if os(iOS)
            Color(.placeholderText)
            #else
            Color(nsColor: .placeholderTextColor)
            #endif
        }()
    }

    // MARK: - Separator

    static var separator: Color {
        #if os(iOS)
        Color(.separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    // MARK: - Brand & State

    enum Brand {
        /// Dozy primary accent. AccentColor 가 비어 있어 sRGB 로 명시.
        /// #5B6EFF
        static let primary = Color(.sRGB, red: 0x5B / 255.0, green: 0x6E / 255.0, blue: 0xFF / 255.0, opacity: 1)
        /// #7C5CCC
        static let secondary = Color(.sRGB, red: 0x7C / 255.0, green: 0x5C / 255.0, blue: 0xCC / 255.0, opacity: 1)
    }

    enum State {
        /// #34C759
        static let success = Color(.sRGB, red: 0x34 / 255.0, green: 0xC7 / 255.0, blue: 0x59 / 255.0, opacity: 1)
        /// #FF9F0A
        static let warning = Color(.sRGB, red: 0xFF / 255.0, green: 0x9F / 255.0, blue: 0x0A / 255.0, opacity: 1)
        /// #FF3B30
        static let danger = Color(.sRGB, red: 0xFF / 255.0, green: 0x3B / 255.0, blue: 0x30 / 255.0, opacity: 1)
        /// #0A84FF
        static let info = Color(.sRGB, red: 0x0A / 255.0, green: 0x84 / 255.0, blue: 0xFF / 255.0, opacity: 1)
    }
}
