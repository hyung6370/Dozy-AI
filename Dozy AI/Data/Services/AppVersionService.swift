//
//  AppVersionService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/13/26.
//
//  ─── Supabase 사전 설정 필요 ─────────────────────────────────────────────────
//  아래 SQL을 Supabase 대시보드 > SQL Editor에서 실행하세요:
//
//  CREATE TABLE IF NOT EXISTS app_config (
//    key        TEXT PRIMARY KEY,
//    value      TEXT NOT NULL,
//    updated_at TIMESTAMPTZ DEFAULT NOW()
//  );
//
//  -- 비로그인 사용자도 읽을 수 있도록 공개 읽기 정책 설정
//  ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
//  CREATE POLICY "Public read" ON app_config FOR SELECT TO anon USING (true);
//
//  -- 초기 최소 지원 버전 삽입 (필요 시 UPDATE로 변경)
//  INSERT INTO app_config (key, value) VALUES ('min_ios_version', '1.0.0')
//    ON CONFLICT (key) DO NOTHING;
//  ─────────────────────────────────────────────────────────────────────────────

import Foundation
import Supabase
import OSLog

final class AppVersionService {

    // MARK: - 현재 앱 버전

    /// CFBundleShortVersionString (예: "1.2.3")
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - 최소 지원 버전 조회

    /// Supabase `app_config` 테이블에서 `min_ios_version` 값을 비동기로 가져옵니다.
    /// - 조회 실패(오프라인 / 테이블 없음)는 `nil`을 반환해 앱 진입을 막지 않습니다 (fail-open).
    func fetchMinimumVersion() async -> String? {
        do {
            let rows: [AppConfigRow] = try await supabase
                .from("app_config")
                .select("key, value")
                .eq("key", value: "min_ios_version")
                .execute()
                .value
            return rows.first?.value
        } catch {
            Logger.network.warning("⚠️ 최소 버전 조회 실패 — 업데이트 체크 건너뜀: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 버전 비교

    /// `currentVersion`이 `minimumVersion`보다 낮으면 `true` (강제 업데이트 필요).
    /// "1.0.9" < "1.1.0" 처럼 시맨틱 버전을 올바르게 비교합니다.
    func isUpdateRequired(minimumVersion: String) -> Bool {
        currentVersion.compare(minimumVersion, options: .numeric) == .orderedAscending
    }
}

// MARK: - DTO

private struct AppConfigRow: Decodable {
    let key: String
    let value: String
}
