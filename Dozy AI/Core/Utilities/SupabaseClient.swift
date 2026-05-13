//
//  SupabaseClient.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation
import Supabase
import OSLog

var supabase: SupabaseClient = buildSupabaseClient()

/// 환경 선택 후 supabase를 올바른 환경으로 재초기화합니다.
/// DEBUG 전용 — AppCoordinator.setup() 진입 시 AppEnvironment 설정 직후 호출.
func rebuildSupabaseClient() {
    supabase = buildSupabaseClient()
}

private func buildSupabaseClient() -> SupabaseClient {
    let info = Bundle.main.infoDictionary ?? [:]

    #if DEBUG
    let hostKey = AppEnvironment.current == .production ? "PROD_SUPABASE_HOST" : "SUPABASE_HOST"
    let anonKey = AppEnvironment.current == .production ? "PROD_SUPABASE_ANON_KEY" : "SUPABASE_ANON_KEY"
    let host = info[hostKey] as? String ?? ""
    let key  = info[anonKey] as? String ?? ""
    #else
    let host = info["SUPABASE_HOST"] as? String ?? ""
    let key  = info["SUPABASE_ANON_KEY"] as? String ?? ""
    #endif

    guard !host.isEmpty, !key.isEmpty, let url = URL(string: "https://\(host)") else {
        fatalError("⚠️ SUPABASE_HOST 또는 SUPABASE_ANON_KEY가 Info.plist에 없습니다. Secrets.xcconfig가 빌드 설정에 연결되어 있는지 확인하세요.")
    }

    #if DEBUG
    Logger.app.info("🔌 Supabase 연결: \(AppEnvironment.current.displayName) → \(host)")
    #else
    Logger.app.info("🔌 Supabase 연결: Production → \(host)")
    #endif

    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: key,
        options: .init(
            auth: .init(
                // ⚠️ macOS 리뷰 리젝 (4e056eac) 해결 — 기본 KeychainLocalStorage 가
                // macOS legacy file-based keychain 사용해 첫 실행 시 user 의 login
                // keychain password prompt 가 떴음. DozyAuthLocalStorage 는
                // `kSecUseDataProtectionKeychain` 으로 modern keychain 사용 → prompt 없음.
                storage: DozyAuthLocalStorage(),
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
