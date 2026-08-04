//
//  AIResponseParserTests.swift
//  Dozy AITests
//
//  Created by Hyungjun KIM on 8/3/26.
//

import Foundation
import Testing
@testable import Dozy_AI

@Suite("AIResponseParser")
struct AIResponseParserTests {
    
    private let testDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 11
        return Calendar.current.date(from: c)!
    }()
    
    // 매번 4개 인자를 쓰지 않도록 감싼 헬퍼
    private func parse(
        _ response: String,
        events: [CalendarEvent] = [],
        tasks: [TaskItem] = []
    ) -> DailySummary {
        AIResponseParser.parse(
            response: response,
            date: testDate,
            events: events,
            completedTasks: tasks
        )
    }
    
    // MARK: - 정상 응답
    @Test("모든 섹션이 있는 응답을 파싱한다")
    func 정상_응답_전체_파싱() {
        let response = """
            [Summary]
            오늘은 회의가 많았습니다.
            
            [Highlights]
            - 팀 회의 진행
            - 코드 리뷰 완료
            
            [Next Actions]
            - 문서 정리
            
            [Category]
            개발
            
            [Score]
            0.85
            """
        
        let result = parse(response)
        
        #expect(result.summaryText == "오늘은 회의가 많았습니다.")
        #expect(result.highlights == ["팀 회의 진행", "코드 리뷰 완료"])
        #expect(result.nextActions == ["문서 정리"])
        #expect(result.detectedCategory == "개발")
        #expect(result.productivityScore == 0.85)
        #expect(result.date == testDate)
    }
    
    // MARK: - Summary
    @Test("한글 레거시 태그 [요약] 도 인식한다")
    func 한글_태그_인식() {
        #expect(parse("[요약]\n오늘의 기록").summaryText == "오늘의 기록")
    }

    @Test("태그 대소문자를 구분하지 않는다")
    func 태그_대소문자_무시() {
        #expect(parse("[summary]\n소문자 태그").summaryText == "소문자 태그")
    }

    @Test("영문·한글 태그가 함께 있으면 영문이 우선한다")
    func 영문_태그_우선() {
        let response = """
        [Summary]
        영문 섹션

        [요약]
        한글 섹션
        """
        #expect(parse(response).summaryText == "영문 섹션")
    }

    @Test("Summary 태그가 없으면 응답 앞 200자를 그대로 쓴다")
    func 태그_없으면_prefix_폴백() {
        let result = parse("태그가 전혀 없는 자유 형식 응답입니다")
        #expect(result.summaryText == "태그가 전혀 없는 자유 형식 응답입니다")
    }

    @Test("prefix 폴백은 200자에서 잘린다")
    func prefix_200자_경계() {
        let result = parse(String(repeating: "가", count: 250))
        #expect(result.summaryText.count == 200)
    }
    
    // MARK: - Highlights (리스트)
    @Test("리스트 접두사가 제거된다", arguments: [
        ("- 항목", "항목"),
        ("• 항목", "항목"),
        ("* 항목", "항목"),
        ("1. 항목", "항목"),
        ("10. 항목", "항목"),
        ("항목", "항목"),
    ])
    func 리스트_접두사_제거(line: String, expected: String) {
        #expect(parse("[Highlights]\n\(line)").highlights == [expected])
    }
    
    @Test("빈 줄은 무시된다")
    func 빈_줄_무시() {
        let response = """
            [Highlights]
            - 첫째
            
            - 둘째
            """
        #expect(parse(response).highlights == ["첫째", "둘째"])
    }
    
    @Test("대소문자 무시 중복 제거 — 먼저 나온 표기가 남는다")
    func 중복_제거() {
        let result = parse("[Highlights]\n- Foo\n- foo\n- FOO")
        #expect(result.highlights == ["Foo"])
    }
    
    // MARK: - 로컬라이제이션 함정
    @Test("Highlights 섹션이 없으면 이벤트·태스크로 폴백을 생성한다")
    func 하이라이트_폴백_생성() {
        let events = [
            makeTestEvent(title: "긴 회의", startHour: 9, endHour: 12),
            makeTestEvent(title: "짧은 회의", startHour: 14, endHour: 15),
        ]
        let result = parse("[Summary]\n요약만 있음", events: events, tasks: [makeTestTask()])
        
        // 문자열 자체를 단언하지 않는다 — 개수와 '가장 긴 이벤트 제목' 포함만 확인
        #expect(result.highlights.count == 3)
        #expect(result.highlights.contains { $0.contains("긴 회의") })
    }
    
    @Test("이벤트·태스크가 모두 없으면 하이라이트는 빈 배열이다")
    func 하이라이트_폴백_없음() {
        #expect(parse("[Summary]\n요약").highlights.isEmpty)
    }
    
    // MARK: - Next Actions (Highlights와 다른 점)
    @Test("공백이 포함된 태그도 인식한다")
    func 공백_포함_태그() {
        #expect(parse("[Next Actions]\n- 문서 작성").nextActions == ["문서 작성"])
    }
    
    @Test("한글 레거시 태그 [추천 할 일] 도 인식한다")
    func 한글_액션_태그() {
        #expect(parse("[추천 할 일]\n- 회고 작성").nextActions == ["회고 작성"])
    }
    
    @Test("Next Actions 는 폴백이 없어 빈 배열로 남는다")
    func 액션_폴백_없음() {
        let result = parse("[Summary]\n요약", events: [makeTestEvent()], tasks: [makeTestTask()])
        #expect(result.nextActions.isEmpty)
    }
    
    // MARK: - Category
    @Test("응답의 카테고리를 그대로 사용한다")
    func 카테고리_추출() {
        #expect(parse("[Category]\n개발").detectedCategory == "개발")
    }
    
    @Test("카테고리 태그가 없으면 이벤트의 최빈 카테고리를 쓴다")
    func 카테고리_최빈값_폴백() {
        let events = [
            makeTestEvent(category: "개발"),
            makeTestEvent(category: "개발"),
            makeTestEvent(category: "회의"),
        ]
        #expect(parse("[Summary]\n요약", events: events).detectedCategory == "개발")
    }
    
    @Test("이벤트가 모두 기본 카테고리면 기본값을 쓴다")
    func 카테고리_전부_기본값() {
        let events = [makeTestEvent(category: "일반"), makeTestEvent(category: "일반")]
        #expect(parse("[Summary]\n요약", events: events).detectedCategory == UserCategory.defaultName)
    }
    
    @Test("이벤트도 없으면 기본 카테고리를 쓴다")
    func 카테고리_이벤트_없음() {
        #expect(parse("[Summary]\n요약").detectedCategory == UserCategory.defaultName)
    }
    
    // MARK: - Score
    @Test("Score 를 파싱하고 0...1 로 클램프한다", arguments: [
        ("0.85", 0.85),
        ("0",    0.0),
        ("1",    1.0),
        ("1.5",  1.0),
        ("-0.3", 0.0),
    ])
    func 점수_파싱과_클램프(raw: String, expected: Double) {
        #expect(parse("[Score]\n\(raw)").productivityScore == expected)
    }
    
    @Test("Score 태그가 없으면 완료 태스크 수로 계산한다", arguments: [
        (0,  0.5),      // 완료 0건은 중립값 0.5
        (1,  0.125),
        (2,  0.25),
        (8,  1.0),
        (10, 1.0),      // 8건 초과는 1.0 로 클램프
    ])
    func 점수_폴백_계산(taskCount: Int, expected: Double) {
        let tasks = (0..<taskCount).map { makeTestTask(title: "할 일 \($0)") }
        #expect(parse("[Summary]\n요약", tasks: tasks).productivityScore == expected)
    }
    
    // MARK: - 꺠진 입력 / 현재 동작 문서화
    @Test("빈 응답도 크래시 없이 기본값을 반환한다")
    func 빈_응답() {
        let result = parse("")
        #expect(result.summaryText.isEmpty)
        #expect(result.highlights.isEmpty)
        #expect(result.nextActions.isEmpty)
        #expect(result.detectedCategory == UserCategory.defaultName)
        #expect(result.productivityScore == 0.5)
        #expect(result.totalEventMinutes == 0)
        #expect(result.completedTaskCount == 0)
    }
    
    @Test("코드펜스로 감싼 응답에서 백틱을 제거한다", arguments: [
        "```\n[Summary]\n오늘은 바빴습니다\n```",       // 언어 표기 없는 펜스
        "```json\n[Summary]\n오늘은 바빴습니다\n```",   // 언어 표기가 붙은 펜스
        "[Summary]\n오늘은 바빴습니다",                  // 펜스 없는 응답도 그대로 동작
    ])
    func 코드펜스_제거(response: String) {
        #expect(parse(response).summaryText == "오늘은 바빴습니다")
    }

    // 본문 중간의 백틱은 의도된 내용일 수 있어 보존한다.
    @Test("본문 내부의 백틱은 남긴다")
    func 본문_백틱_보존() {
        #expect(parse("[Summary]\n`코드` 리뷰를 했습니다").summaryText == "`코드` 리뷰를 했습니다")
    }

    @Test("퍼센트 표기 점수를 0...1 스케일로 변환한다", arguments: [
        ("85%",  0.85),
        ("100%", 1.0),
        ("0%",   0.0),
        ("85 %", 0.85),   // 숫자와 % 사이 공백
    ])
    func 퍼센트_점수_변환(raw: String, expected: Double) {
        #expect(parse("[Score]\n\(raw)").productivityScore == expected)
    }
    
    // 🔍 다음 섹션이 줄바꿈 없이 인라인으로 오면 요약이 그것까지 삼킨다.
    @Test("인라인 섹션은 요약에 흡수된다")
    func 인라인_섹션_흡수() {
        let result = parse("[Summary]\n첫 문장 [Category] 업무")
        #expect(result.summaryText.contains("[Category]"))
        #expect(result.detectedCategory == "업무")   // 카테고리 추출 자체는 정상
    }
    
    // MARK: - 집계 값
    @Test("종일 이벤트는 총 소요시간에서 제외된다")
    func 종일_이벤트_제외() {
        let events = [
            makeTestEvent(startHour: 9, endHour: 10),                  // 60분
            makeTestEvent(startHour: 14, endHour: 16),                 // 120분
            makeTestEvent(startHour: 9, endHour: 10, isAllDay: true),  // 제외
        ]
        #expect(parse("[Summary]\n요약", events: events).totalEventMinutes == 180)
    }
    
    @Test("완료 태스크 수가 그대로 반영된다")
    func 완료_태스크_수() {
        let tasks = [makeTestTask(title: "A"), makeTestTask(title: "B")]
        #expect(parse("[Summary]\n요약", tasks: tasks).completedTaskCount == 2)
    }
}
