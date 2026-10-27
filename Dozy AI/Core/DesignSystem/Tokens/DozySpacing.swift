//
//  DozySpacing.swift
//  Dozy AI
//
//  간격 스케일. 4의 배수를 기본으로 한다.
//

import CoreGraphics

enum DozySpacing {
    /// 2 — 극히 좁은 간격 (배지 내부, 마이크로 여백).
    static let xxxs: CGFloat = 2
    /// 4 — 인접 요소 사이.
    static let xxs: CGFloat = 4
    /// 8 — 기본 좁은 간격.
    static let xs: CGFloat = 8
    /// 12 — 행 내 컴포넌트 간격.
    static let sm: CGFloat = 12
    /// 16 — 카드/섹션 기본 패딩.
    static let md: CGFloat = 16
    /// 20 — 컴팩트 섹션 간격.
    static let lg: CGFloat = 20
    /// 24 — 섹션 간격.
    static let xl: CGFloat = 24
    /// 32 — 큰 그룹 간격.
    static let xxl: CGFloat = 32
    /// 40 — 화면 상단 여백 등.
    static let xxxl: CGFloat = 40
    /// 48
    static let xxxxl: CGFloat = 48
}
