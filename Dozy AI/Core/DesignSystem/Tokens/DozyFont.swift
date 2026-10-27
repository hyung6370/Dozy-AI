//
//  DozyFont.swift
//  Dozy AI
//
//  시맨틱 폰트 토큰. SwiftUI 의 TextStyle 기반이라 Dynamic Type 자동 대응.
//  - 의미 단위(title/body/caption …)로 사용처를 고정한다.
//  - weight 변형은 helper 로 노출한다.
//

import SwiftUI

enum DozyFont {
    // MARK: - Display / Title

    /// 화면 최상단 큰 제목.
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    /// 섹션 헤더, 모달 타이틀.
    static let title = Font.system(.title, design: .default, weight: .semibold)
    /// 카드 타이틀.
    static let title2 = Font.system(.title2, design: .default, weight: .semibold)
    /// 작은 카드 타이틀 / 리스트 헤더.
    static let title3 = Font.system(.title3, design: .default, weight: .semibold)

    // MARK: - Body

    /// 강조된 본문 (리스트 행 제목 등).
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    /// 기본 본문.
    static let body = Font.system(.body, design: .default, weight: .regular)
    /// 강조 본문.
    static let bodyEmphasized = Font.system(.body, design: .default, weight: .semibold)
    /// 보조 본문, 행 부제목.
    static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)
    static let subheadlineEmphasized = Font.system(.subheadline, design: .default, weight: .semibold)
    /// 버튼 라벨 등 본문보다 약간 작은 사이즈.
    static let callout = Font.system(.callout, design: .default, weight: .regular)

    // MARK: - Caption

    /// 메타데이터.
    static let footnote = Font.system(.footnote, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let captionEmphasized = Font.system(.caption, design: .default, weight: .semibold)
    static let caption2 = Font.system(.caption2, design: .default, weight: .regular)

    // MARK: - Monospaced

    /// 숫자 정렬이 중요한 곳 (시간, 통계 등).
    static let bodyMono = Font.system(.body, design: .monospaced, weight: .regular)
    static let captionMono = Font.system(.caption, design: .monospaced, weight: .regular)
}
