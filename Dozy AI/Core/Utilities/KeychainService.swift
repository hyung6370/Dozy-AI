//
//  KeychainService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/13/26.
//

import Foundation
import Security

/// 민감한 데이터(displayName 등)를 Keychain에 안전하게 저장/조회/삭제하는 헬퍼.
/// Supabase SDK가 인증 토큰은 자체적으로 Keychain에 저장하므로
/// 이 서비스는 SDK가 다루지 않는 추가 데이터(예: displayName)에만 사용합니다.
enum KeychainService {

    private static let service = Bundle.main.bundleIdentifier ?? "com.dozy-ai.Dozy-AI"

    /// Keychain에 문자열 값을 저장합니다. 기존 값이 있으면 덮어씁니다.
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(base as CFDictionary)
        let add = base.merging([kSecValueData: data] as [CFString: Any]) { $1 }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// Keychain에서 문자열 값을 읽어옵니다. 없으면 nil 반환.
    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Keychain에서 값을 삭제합니다.
    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
