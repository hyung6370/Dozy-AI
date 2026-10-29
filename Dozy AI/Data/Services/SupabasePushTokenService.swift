//
//  SupabasePushTokenService.swift
//  Dozy AI
//
//  [Data Layer] APNs 토큰을 Supabase `push_tokens` 에 저장 (#95).
//  등록은 RPC `register_push_token` — 같은 토큰이 다른 계정 행에 있으면(같은 기기에서 계정 전환) 소유자를 옮겨야 하는데,
//  RLS 로는 남의 행을 고칠 수 없어 서버 함수가 auth.uid() 기준으로 처리한다. 해제는 본인 행 DELETE.
//

import Foundation
import Supabase
import OSLog

final class SupabasePushTokenService: PushTokenServiceProtocol {

    private struct RegisterParams: Encodable {
        let p_token: String
        let p_platform: String
        let p_environment: String
        let p_shared_enabled: Bool
    }

    func isSignedIn() async -> Bool {
        (try? await supabase.auth.session) != nil
    }

    func register(token: String, platform: String, environment: String, sharedNotificationsEnabled: Bool) async throws {
        try await supabase
            .rpc("register_push_token", params: RegisterParams(
                p_token: token, p_platform: platform,
                p_environment: environment, p_shared_enabled: sharedNotificationsEnabled
            ))
            .execute()
        Logger.push.info("푸시 토큰 등록 (\(environment, privacy: .public), 공유 알림 \(sharedNotificationsEnabled ? "켬" : "끔", privacy: .public))")
    }

    func unregister(token: String) async throws {
        try await supabase
            .from("push_tokens")
            .delete()
            .eq("token", value: token)
            .execute()
        Logger.push.info("푸시 토큰 해제")
    }
}
