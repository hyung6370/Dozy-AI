//
//  PasswordFailLimiter.swift
//  Dozy AI
//
//  비밀번호 실패 카운트를 관리하는 순수 value type.
//  SwiftUI @State 안에서 mutating 으로 호출되며, 별도 단위 테스트로 검증 가능.
//

import Foundation

struct PasswordFailLimiter: Equatable {
    let threshold: Int
    private(set) var count: Int = 0

    /// 카운트가 threshold 에 도달했는가 (초과 포함).
    var hasReachedLimit: Bool { count >= threshold }

    /// 카운트가 정확히 threshold 인 순간 — alert 자동 트리거에 사용.
    var justReachedLimit: Bool { count == threshold }

    /// 로그인 버튼 활성 가능 여부.
    var canSubmit: Bool { !hasReachedLimit }

    mutating func recordFailure() {
        count += 1
    }

    mutating func reset() {
        count = 0
    }
}
