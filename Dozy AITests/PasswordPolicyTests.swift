//
//  PasswordPolicyTests.swift
//  Dozy AITests
//
//  Created by Hyungjun KIM on 7/31/26.
//

import XCTest
@testable import Dozy_AI

final class PasswordPolicyTests: XCTestCase {
    
    // MARK: - hasValidLength (경계값)
    func test_hasValidLength_sevenChars_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasValidLength(String(repeating: "a", count: 7)))
    }
    
    func test_hasValidLength_eightChars_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasValidLength(String(repeating: "a", count: 8)))
    }
    
    func test_hasValidLength_seventyTwoChars_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasValidLength(String(repeating: "a", count: 72)))
    }
    
    func test_hasValidLength_seventyThreeChars_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasValidLength(String(repeating: "a", count: 73)))
    }
    
    func test_hasValidLength_emptyString_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasValidLength(""))
    }
    
    // MARK: - hasUppercase
    func test_hasUppercase_containsUppercase_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasUppercase("abcDef"))
    }
    
    func test_hasUppercase_lowercaseOnly_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasUppercase("abcdef123!"))
    }
    
    func test_hasUppercase_emptyString_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasUppercase(""))
    }
    
    // MARK: - hasDigit
    func test_hasDigit_containsDigit_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasDigit("abc1def"))
    }
    
    func test_hasDigit_noDigit_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasDigit("abcDef!"))
    }
    
    // MARK: - hasSpecial
    func test_hasSpecial_containsSymbol_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasSpecial("abc!123"))
    }
    
    func test_hasSpecial_alphanumericOnly_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasSpecial("abcABC123"))
    }
    
    // 정규식이 [^A-Za-z0-9] 이므로 한글도 '기호'로 인정된다 - 현재 동작 문서화
    func test_hasSpecial_koreanCharacter_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasSpecial("비밀번호abc123"))
    }
    
    // 공백도 '기호'로 인정된다 - 현재 동작 문서화
    func test_hasSpecial_whitespace_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasSpecial("abc 123"))
    }
    
    // MARK: - hasCharacterVariety - 조건이 하나씩만 빠진 케이스
    func test_hasCharacterVariety_allThree_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.hasCharacterVariety("Abc123!"))
    }

    func test_hasCharacterVariety_missingUppercase_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasCharacterVariety("abc123!"))
    }

    func test_hasCharacterVariety_missingDigit_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasCharacterVariety("Abcdef!"))
    }

    func test_hasCharacterVariety_missingSpecial_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.hasCharacterVariety("Abc1234"))
    }
    
    // MARK: - isNotCommon - 대소문자 함정
    func test_isNotCommon_blocklistedPassword_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isNotCommon("password123"))
    }
    
    // lowercased() 비교이므로 대문자로 써도 블록된다
    func test_isNotCommon_blocklistedInUppercase_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isNotCommon("PASSWORD123"))
    }
    
    // 정확히 일치할 때만 블록 - 한 글자만 더 붙어도 통과한다
    func test_isNotCommon_similarButNotExact_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.isNotCommon("password1234"))
    }
    
    func test_isNotCommon_uncommonPassword_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.isNotCommon("MyDozy!2026"))
    }
    
    // MARK: - isNotSameAsEmail - 비대칭 처리
    func test_isNotSameAsEmail_identical_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isNotSameAsEmail("hyung@test.com", email: "hyung@test.com"))
    }

    func test_isNotSameAsEmail_different_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.isNotSameAsEmail("MyDozy!2026", email: "hyung@test.com"))
    }

    // 대소문자만 다른 경우도 동일한 것으로 취급된다.
    func test_isNotSameAsEmail_caseInsensitive_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isNotSameAsEmail("Hyung@Test.com", email: "hyung@test.com"))
    }

    // 이메일 쪽 공백은 trim 되므로 동일 판정.
    func test_isNotSameAsEmail_emailWithSurroundingSpaces_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isNotSameAsEmail("hyung@test.com", email: " hyung@test.com "))
    }

    // 비밀번호 쪽 공백은 trim 되지 않는다 — 비대칭 동작 문서화.
    func test_isNotSameAsEmail_passwordWithLeadingSpace_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.isNotSameAsEmail(" hyung@test.com", email: "hyung@test.com"))
    }
    
    // MARK: - isValid - 조건이 하나씩만 실패하도록 입력 설계
    private let email = "hyung@test.com"
    
    func test_isValid_allPoliciesPass_returnsTrue() {
        XCTAssertTrue(PasswordPolicy.isValid("MyDozy!2026", email: email))
    }
    
    // 길이만 미달 (7자, 다양성, 비블록, 비이메일은 통과)
    func test_isValid_onlyLengthFails_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isValid("Ab!4567", email: email))
    }
    
    // 다양성만 미달 (10자 소문자, 블록리스트에 없음)
    func test_isValid_onlyVarietyFails_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isValid("abcdefghij", email: email))
    }
    
    // 흔한 비번만 걸림 - "P@ssw0rd"는 8자 + 대문자/숫자/기호 통과
    // lowercased 하면 블록리스트의 "p@ssw0rd"와 일치
    func test_isValid_onlyCommonPasswordFails_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isValid("P@ssw0rd", email: email))
    }
    
    // 이메일 동일만 걸림 - 길이/다양성/비블록은 통과하는 이메일을 사용
    func test_isValid_onlySameAsEmailFails_returnsFalse() {
        XCTAssertFalse(PasswordPolicy.isValid("User1!@dozy.ai", email: "user1!@dozy.ai"))
    }
    
    // MARK: - 심화: 정책의 숨은 성질 문서화
    
    // count 는 grapheme(문자) 단위 — 이모지 70개는 '70자'로 통과한다.
    // 단, UTF-8 로는 280바이트라 bcrypt 의 72바이트 한계를 초과한다.
    func test_hasValidLength_seventyEmoji_returnsTrue_butExceedsBcryptByteLimit() {
        let password = String(repeating: "🔒", count: 70)
        XCTAssertTrue(PasswordPolicy.hasValidLength(password))
        XCTAssertGreaterThan(password.utf8.count, 72)
    }

    // 한글이 '기호'로 인정되므로 한글+대문자+숫자 조합은 isValid 를 통과한다.
    func test_isValid_koreanCountsAsSpecial_passes() {
        XCTAssertTrue(PasswordPolicy.isValid("한글비밀번호A1", email: email))
    }
}
