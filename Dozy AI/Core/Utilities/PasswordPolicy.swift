//
//  PasswordPolicy.swift
//  Dozy AI
//
//  비밀번호 검증 정책. View 가 실시간 체크리스트 노출에, ViewModel·Service 가
//  최종 가드에 같이 사용. NIST 2020+ 권장에 가까운 톤 (긴 비번 > 복잡한 규칙)
//  + 약간의 문자 변형 강제 + 흔한 비번 블록 + 이메일 일치 차단.
//

import Foundation

enum PasswordPolicy {

    static let minLength = 8
    static let maxLength = 72   // bcrypt 한계

    /// 길이 조건.
    static func hasValidLength(_ password: String) -> Bool {
        (minLength...maxLength).contains(password.count)
    }

    /// 영문 대문자 포함.
    static func hasUppercase(_ password: String) -> Bool {
        password.range(of: "[A-Z]", options: .regularExpression) != nil
    }

    /// 숫자 포함.
    static func hasDigit(_ password: String) -> Bool {
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }

    /// 기호 (영문자/숫자가 아닌 어떤 문자) 포함.
    static func hasSpecial(_ password: String) -> Bool {
        password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }

    /// 영문 대문자 · 숫자 · 기호 **모두** 포함되어야 통과.
    static func hasCharacterVariety(_ password: String) -> Bool {
        hasUppercase(password) && hasDigit(password) && hasSpecial(password)
    }

    /// 흔한 비밀번호 블록리스트에 없는지.
    static func isNotCommon(_ password: String) -> Bool {
        !commonPasswords.contains(password.lowercased())
    }

    /// 이메일 자체와 동일하지 않은지.
    static func isNotSameAsEmail(_ password: String, email: String) -> Bool {
        password.lowercased() != email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 모든 정책 통과 여부.
    static func isValid(_ password: String, email: String) -> Bool {
        hasValidLength(password)
            && hasCharacterVariety(password)
            && isNotCommon(password)
            && isNotSameAsEmail(password, email: email)
    }

    /// 흔한 비밀번호 블록리스트 — 유출 dump 상위에서 추린 약 50개.
    /// 추가/갱신은 https://github.com/danielmiessler/SecLists 등 참고.
    private static let commonPasswords: Set<String> = [
        "12345678", "123456789", "1234567890", "password", "password1",
        "password123", "qwerty123", "qwerty1234", "qwertyuiop", "1q2w3e4r",
        "1q2w3e4r5t", "abcd1234", "abcdefgh", "asdfghjkl", "zxcvbnm123",
        "admin123", "admin1234", "administrator", "letmein123", "welcome1",
        "welcome123", "passw0rd", "p@ssw0rd", "iloveyou", "iloveyou1",
        "00000000", "11111111", "22222222", "00112233", "12341234",
        "princess", "sunshine", "monkey123", "dragon123", "master123",
        "superman", "batman123", "trustno1", "qazwsxedc", "qazwsx123",
        "test1234", "guest1234", "baseball1", "football1", "michael1",
        "jordan23", "666666666", "qq123456", "asdasd123", "12121212"
    ]
}
