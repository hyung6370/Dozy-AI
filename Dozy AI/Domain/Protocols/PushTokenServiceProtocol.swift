//
//  PushTokenServiceProtocol.swift
//  Dozy AI
//
//  APNs 디바이스 토큰 서버 저장 (#95). 구현은 Data 의 SupabasePushTokenService, macOS · 테스트는 Noop.
//

import Foundation

protocol PushTokenServiceProtocol {
    /// 서버에 올릴 수 있는 상태(로그인 세션 있음)인지
    func isSignedIn() async -> Bool
    /// 현재 로그인 사용자 소유로 토큰을 저장한다. 같은 토큰이 다른 계정에 있으면 소유자를 옮긴다.
    func register(token: String, platform: String, environment: String, sharedNotificationsEnabled: Bool) async throws
    /// 로그아웃 직전에 부른다 — 로그아웃 뒤에는 RLS 로 본인 행을 지울 수 없다.
    func unregister(token: String) async throws
}

final class NoopPushTokenService: PushTokenServiceProtocol {
    init() {}
    func isSignedIn() async -> Bool { false }
    func register(token: String, platform: String, environment: String, sharedNotificationsEnabled: Bool) async throws {}
    func unregister(token: String) async throws {}
}
