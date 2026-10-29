//
//  PushRegistrationUseCase.swift
//  Dozy AI
//
//  APNs 토큰 등록 · 해제 (#95).
//  - 토큰은 AppDelegate 가 받는 즉시 기기에 저장하고, 로그인 상태면 서버에 올린다
//  - 로그인 직후 · 포그라운드 복귀 때 다시 올려 서버 행을 최신으로 맞춘다 (토큰은 바뀔 수 있다)
//  - 로그아웃은 세션이 사라지기 전에 서버 행을 지운다
//

import Foundation

final class PushRegistrationUseCase {

    private let service: PushTokenServiceProtocol
    private let defaults: UserDefaults
    private let environment: String
    private let platform: String

    init(
        service: PushTokenServiceProtocol,
        defaults: UserDefaults = .standard,
        environment: String = PushSettings.apnsEnvironment,
        platform: String = "ios"
    ) {
        self.service = service
        self.defaults = defaults
        self.environment = environment
        self.platform = platform
    }

    /// AppDelegate 가 새 토큰을 받았을 때
    func updateToken(_ token: String) async {
        PushSettings.setDeviceToken(token, defaults: defaults)
        await registerIfPossible()
    }

    /// 로그인 상태이고 토큰이 있으면 서버에 저장 (upsert). 실패는 다음 기회(포그라운드 복귀)에 다시 시도.
    func registerIfPossible() async {
        guard let token = PushSettings.deviceToken(defaults: defaults), await service.isSignedIn() else { return }
        do {
            try await service.register(
                token: token, platform: platform, environment: environment,
                sharedNotificationsEnabled: PushSettings.isSharedNotificationsEnabled(defaults: defaults)
            )
        } catch {
            CrashReporting.record(error, context: "push.register_token")
        }
    }

    /// 로그아웃 직전 — 이 기기로 이전 계정의 푸시가 오지 않게
    func unregister() async {
        guard let token = PushSettings.deviceToken(defaults: defaults) else { return }
        do {
            try await service.unregister(token: token)
        } catch {
            CrashReporting.record(error, context: "push.unregister_token")
        }
    }

    /// 설정 "공유 캘린더 알림" — 기기에 저장하고 서버 플래그도 맞춘다 (서버는 꺼진 토큰을 건너뛴다)
    func setSharedNotificationsEnabled(_ enabled: Bool) async {
        PushSettings.setSharedNotificationsEnabled(enabled, defaults: defaults)
        await registerIfPossible()
    }
}
