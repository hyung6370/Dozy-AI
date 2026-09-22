//
//  CalendarHeaderSymbolsTests.swift
//  Dozy AITests
//

import Testing
import Foundation
@testable import Dozy_AI

@Suite("Calendar.headerWeekdaySymbols")
struct CalendarHeaderSymbolsTests {

    @Test("영문 로케일에서는 3글자 대문자 요일이 나온다")
    func 요일심볼_영문() {
        #expect(Calendar.headerWeekdaySymbols(locale: Locale(identifier: "en_US"))
                == ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"])
    }

    @Test("한국어 로케일은 기존 표기를 그대로 유지한다")
    func 요일심볼_한국어() {
        #expect(Calendar.headerWeekdaySymbols(locale: Locale(identifier: "ko_KR"))
                == ["일", "월", "화", "수", "목", "금", "토"])
    }

    @Test("firstWeekday 설정과 무관하게 항상 일요일부터 시작한다")
    func 요일심볼_항상일요일시작() {
        // 그리드가 일요일 시작으로 그려지므로 인덱스 0 이 일요일이어야 색상 판정이 맞는다.
        #expect(Calendar.headerWeekdaySymbols(locale: Locale(identifier: "en_GB")).first == "SUN")
    }
}
