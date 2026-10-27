//
//  LiveActivityServiceProtocol.swift
//  Dozy AI
//
//  [Domain] "오늘 아젠다" Live Activity 를 시작·갱신·종료하는 서비스 추상화.
//  ActivityKit 은 iOS 전용이므로 macOS 는 아무것도 하지 않는 구현을 꽂는다.
//

import Foundation

protocol LiveActivityServiceProtocol {
    /// 플래너 결과를 액티비티에 반영한다. `.end` 면 내리고, `.show` 면 없을 때 시작·있을 때 갱신.
    @MainActor
    func apply(_ plan: TodayAgendaPlan) async

    /// 떠 있는 액티비티를 전부 즉시 내린다 (설정 끔, 로그아웃 등).
    @MainActor
    func endAll() async
}

/// macOS · 테스트용 — 아무것도 하지 않는다.
final class NoopLiveActivityService: LiveActivityServiceProtocol {
    func apply(_ plan: TodayAgendaPlan) async {}
    func endAll() async {}
}
