//
//  SupabaseClient.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation
import Supabase
import OSLog

let supabase: SupabaseClient = {
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
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}()
