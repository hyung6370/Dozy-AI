//
//  SupabaseAuthLocalStorage.swift
//  Dozy AI
//
//  Supabase Auth SDK 의 session 토큰을 Keychain 에 저장하기 위한 custom storage.
//
//  ⚠️ macOS App Store 리뷰 리젝 (Submission 4e056eac, 2026-05-12) 해결:
//  Supabase SDK 기본 KeychainLocalStorage 가 `kSecUseDataProtectionKeychain` 을
//  설정하지 않아 macOS 에서 legacy file-based keychain 을 사용 → 첫 실행 시
//  "Dozy wants to access key 'supabase.gotrue.swift' ... enter the 'login'
//  keychain password" prompt 가 뜨고 리뷰어가 진행 불가.
//
//  modern data-protection keychain (`kSecUseDataProtectionKeychain: true`) 으로
//  넘기면 sandboxed app 의 own keychain group 내 항목으로 처리돼 prompt 없음.
//  iOS 는 기본이 data-protection keychain 이라 영향 없음.
//

import Foundation
import Supabase
import Security
import OSLog

private let logger = Logger(subsystem: "com.dozy-ai.Dozy-AI", category: "SupabaseAuthStorage")

struct DozyAuthLocalStorage: AuthLocalStorage {

    /// Supabase SDK 기본 service 식별자와 동일하게 유지 — 동일 앱 내 SDK 호환성.
    private let service: String

    init(service: String = "supabase.gotrue.swift") {
        self.service = service
    }

    func store(key: String, value: Data) throws {
        // upsert: 기존 항목 삭제 후 add.
        try? remove(key: key)

        var add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: value,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        #if os(macOS)
        // 핵심 — modern keychain. sandboxed app 의 own keychain group 안에서 처리되어
        // user 의 login keychain password prompt 가 발생하지 않는다.
        add[kSecUseDataProtectionKeychain] = true
        #endif

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain store failed for key=\(key, privacy: .public) status=\(status)")
            throw KeychainError.unhandledError(status: status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain] = true
        #endif

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            logger.error("Keychain retrieve failed for key=\(key, privacy: .public) status=\(status)")
            throw KeychainError.unhandledError(status: status)
        }
        return result as? Data
    }

    func remove(key: String) throws {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain] = true
        #endif

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain remove failed for key=\(key, privacy: .public) status=\(status)")
            throw KeychainError.unhandledError(status: status)
        }
    }

    enum KeychainError: Error {
        case unhandledError(status: OSStatus)
    }
}
