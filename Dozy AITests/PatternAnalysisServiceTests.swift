//
//  PatternAnalysisServiceTests.swift
//  Dozy AITests
//
//  PatternAnalysisService 는 내부에서 Date()/Calendar.current 로 "오늘"을 잡는다.
//  그래서 픽스처는 전부 오늘 기준 상대 날짜(daysAgo)로 만든다 — 어느 날 돌려도 같은 결과.
//  SwiftData @Model(DozyEvent·EventCompletion·WorkLog)은 컨테이너 없이 생성만 해도 프로퍼티 접근이 되므로
//  순수 계산 로직은 in-memory 컨테이너 없이 검증한다.
//

import Testing
import Foundation
@testable import Dozy_AI

@Suite("PatternAnalysisService")
@MainActor
struct PatternAnalysisServiceTests {

    private let sut = PatternAnalysisService()
    private let cal = Calendar.current
    private var today: Date { cal.startOfDay(for: Date()) }

    // MARK: - Fixtures

    private func date(daysAgo: Int, hour: Int = 10) -> Date {
        let day = cal.date(byAdding: .day, value: -daysAgo, to: today)!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func dozy(daysAgo: Int = 0, hour: Int = 10, completed: Bool = false,
                      isAllDay: Bool = false, rule: String = "none") -> DozyEvent {
        let start = date(daysAgo: daysAgo, hour: hour)
        let event = DozyEvent(title: "dozy", startDate: start, endDate: start.addingTimeInterval(3600),
                              isAllDay: isAllDay, recurrenceRule: rule)
        event.isCompleted = completed
        return event
    }

    private func completion(daysAgo: Int = 0, completed: Bool) -> EventCompletion {
        let c = EventCompletion(eventID: UUID().uuidString, eventDate: date(daysAgo: daysAgo))
        c.isCompleted = completed
        return c
    }

    private func calendarEvent(daysAgo: Int = 0, hour: Int = 10, isAllDay: Bool = false) -> CalendarEvent {
        let start = date(daysAgo: daysAgo, hour: hour)
        return CalendarEvent(id: UUID().uuidString, calendarId: nil, title: "cal",
                             startDate: start, endDate: start.addingTimeInterval(3600),
                             location: nil, notes: nil, isAllDay: isAllDay,
                             calendarName: "t", calendarColorHex: "#000000",
                             source: .apple, priority: 0, isPinned: false, category: "일반")
    }

    private func log(daysAgo: Int = 0, category: String = "일반", score: Double? = nil) -> WorkLog {
        let l = WorkLog(date: date(daysAgo: daysAgo))
        l.category = category
        l.productivityScore = score
        return l
    }

    /// 오늘 요일 (0 = 일요일) — 요일 평균 테스트의 기대값 계산용.
    private var todayWeekday: Int { cal.component(.weekday, from: today) - 1 }

    // MARK: - 완료율

    @Test("입력이 비어 있으면 완료율은 0")
    func 완료율_빈입력() {
        #expect(sut.averageCompletionRate(from: []) == 0)
        #expect(sut.averageCompletionRate(from: [], calendarCompletions: []) == 0)
    }

    @Test("도지 일정만: 완료 2 / 전체 4 = 0.5")
    func 완료율_도지만() {
        let events = [dozy(completed: true), dozy(completed: true), dozy(), dozy()]
        #expect(sut.averageCompletionRate(from: events) == 0.5)
    }

    @Test("도지 + 캘린더 완료 체크를 합산한다")
    func 완료율_합산() {
        // 도지 1/2 + 캘린더 1/2 → 2/4
        let rate = sut.averageCompletionRate(
            from: [dozy(completed: true), dozy()],
            calendarCompletions: [completion(completed: true), completion(completed: false)]
        )
        #expect(rate == 0.5)
        // 캘린더만 2/2 → 1.0
        #expect(sut.averageCompletionRate(from: [], calendarCompletions: [completion(completed: true), completion(completed: true)]) == 1.0)
    }

    @Test("변화율: 0.5 → 0.75 는 +0.5")
    func 변화율_정상() {
        let change = sut.completionRateChange(
            current: [dozy(completed: true), dozy(completed: true), dozy(completed: true), dozy()],
            previous: [dozy(completed: true), dozy()]
        )
        #expect(abs(change - 0.5) < 0.0001)
    }

    @Test("변화율: 이전이 0이면 현재가 양수일 때 1.0, 둘 다 0이면 0")
    func 변화율_이전0() {
        #expect(sut.completionRateChange(current: [dozy(completed: true)], previous: [dozy()]) == 1.0)
        #expect(sut.completionRateChange(current: [dozy()], previous: [dozy()]) == 0)
        #expect(sut.completionRateChange(current: [], previous: []) == 0)
    }

    // MARK: - 일별 / 주별 트렌드

    @Test("일별 트렌드: 일정 없는 날은 빠지고, 오래된 날부터 오늘 순으로 비율이 나온다")
    func 일별트렌드_기본() {
        let events = [
            dozy(daysAgo: 2, completed: true), dozy(daysAgo: 2),          // 2일 전 0.5
            dozy(daysAgo: 0, completed: true)                             // 오늘 1.0 (1일 전은 없음)
        ]
        let rates = sut.dailyCompletionRates(from: events, days: 7)
        #expect(rates.count == 2)
        #expect(rates[0].date == date(daysAgo: 2, hour: 0))
        #expect(rates[0].rate == 0.5)
        #expect(rates[1].date == today)
        #expect(rates[1].rate == 1.0)
    }

    @Test("일별 트렌드: days 창 밖의 날은 제외된다 (days=3 → 3일 전 제외, 2일 전 포함)")
    func 일별트렌드_경계() {
        let events = [dozy(daysAgo: 3, completed: true), dozy(daysAgo: 2, completed: true)]
        let rates = sut.dailyCompletionRates(from: events, days: 3)
        #expect(rates.map(\.date) == [date(daysAgo: 2, hour: 0)])
    }

    @Test("일별 트렌드: 캘린더 완료 체크도 같은 날에 합산된다")
    func 일별트렌드_합산() {
        let rates = sut.dailyCompletionRates(
            from: [dozy(daysAgo: 1)],
            calendarCompletions: [completion(daysAgo: 1, completed: true)],
            days: 7
        )
        #expect(rates.count == 1)
        #expect(rates[0].rate == 0.5)
    }

    @Test("주별 트렌드: 이번 주는 오늘을 포함한 7일 — 7일 전은 제외, 오늘·6일 전은 포함, 주 시작일(6일 전)을 날짜로 돌려준다")
    func 주별트렌드_경계() {
        let events = [dozy(daysAgo: 7, completed: true), dozy(daysAgo: 6), dozy(daysAgo: 0, completed: true)]
        let rates = sut.weeklyCompletionRates(from: events, weeks: 1)
        #expect(rates.count == 1)
        #expect(rates[0].date == date(daysAgo: 6, hour: 0))
        #expect(rates[0].rate == 0.5)   // 7일 전이 끼면 2/3, 오늘이 빠지면 0 이 됐을 것
    }

    @Test("주별 트렌드: 지난주 버킷은 13일 전 ~ 7일 전")
    func 주별트렌드_지난주() {
        let events = [dozy(daysAgo: 14, completed: true), dozy(daysAgo: 13), dozy(daysAgo: 7, completed: true)]
        let rates = sut.weeklyCompletionRates(from: events, weeks: 2)
        #expect(rates.map(\.date) == [date(daysAgo: 13, hour: 0)])   // 14일 전은 2주 창 밖, 이번 주는 비어서 제외
        #expect(rates[0].rate == 0.5)
    }

    @Test("주별 트렌드: 일정 없는 주는 빠진다")
    func 주별트렌드_빈주제외() {
        let rates = sut.weeklyCompletionRates(from: [dozy(daysAgo: 1, completed: true)], weeks: 3)
        #expect(rates.count == 1)
    }

    // MARK: - 스트릭

    @Test("스트릭: 오늘 일정이 없으면 오늘은 건너뛰고 어제부터 센다")
    func 스트릭_오늘건너뜀() {
        let events = [dozy(daysAgo: 1, completed: true), dozy(daysAgo: 2, completed: true)]
        #expect(sut.currentStreak(from: events) == 2)
    }

    @Test("스트릭: 달성하지 못한 날에서 끊긴다")
    func 스트릭_미달에서끊김() {
        let events = [dozy(daysAgo: 0, completed: true), dozy(daysAgo: 1), dozy(daysAgo: 2, completed: true)]
        #expect(sut.currentStreak(from: events) == 1)
    }

    @Test("스트릭: 오늘이 아닌 빈 날은 끊김으로 본다")
    func 스트릭_중간빈날() {
        let events = [dozy(daysAgo: 0, completed: true), dozy(daysAgo: 2, completed: true)]
        #expect(sut.currentStreak(from: events) == 1)
    }

    @Test("스트릭: threshold 경계 — 0.5 는 기본값(0.5)에서 달성, 0.6 에서는 미달")
    func 스트릭_threshold() {
        let events = [dozy(completed: true), dozy()]   // 오늘 1/2
        #expect(sut.currentStreak(from: events) == 1)
        #expect(sut.currentStreak(from: events, threshold: 0.6) == 0)
    }

    @Test("스트릭: 캘린더 완료 체크를 합산해 판정한다")
    func 스트릭_합산() {
        // 도지 0/1 + 캘린더 2/2 → 2/3 ≥ 0.5
        let streak = sut.currentStreak(
            from: [dozy()],
            calendarCompletions: [completion(completed: true), completion(completed: true)]
        )
        #expect(streak == 1)
    }

    // MARK: - 시간대

    @Test("시간대 분포: 종일 일정은 제외하고 시간순으로 정렬한다 (CalendarEvent)")
    func 시간대분포_캘린더() {
        let events = [calendarEvent(hour: 14), calendarEvent(hour: 9), calendarEvent(hour: 9), calendarEvent(hour: 9, isAllDay: true)]
        let dist = sut.hourlyDistribution(from: events)
        #expect(dist.map(\.hour) == [9, 14])
        #expect(dist.map(\.count) == [2, 1])
    }

    @Test("시간대 분포: DozyEvent 오버로드도 같은 규칙")
    func 시간대분포_도지() {
        let events = [dozy(hour: 20), dozy(hour: 8), dozy(hour: 8, isAllDay: true)]
        let dist = sut.hourlyDistribution(from: events)
        #expect(dist.map(\.hour) == [8, 20])
        #expect(dist.map(\.count) == [1, 1])
    }

    @Test("피크 시간대: 건수 많은 순으로 최대 3개")
    func 피크시간대() {
        var events: [CalendarEvent] = []
        events += (0..<4).map { _ in calendarEvent(hour: 9) }
        events += (0..<3).map { _ in calendarEvent(hour: 14) }
        events += (0..<2).map { _ in calendarEvent(hour: 20) }
        events += [calendarEvent(hour: 7)]
        #expect(sut.peakHours(from: events) == [9, 14, 20])
        #expect(sut.peakHours(from: [CalendarEvent]()).isEmpty)
    }

    // MARK: - 요일 평균

    @Test("요일 평균(CalendarEvent): 기간을 주 단위로 나눈다 — 14일에 4건이면 2.0, 7일 미만은 1주로 본다")
    func 요일평균_캘린더() {
        let events = (0..<4).map { _ in calendarEvent() }   // 전부 오늘 요일
        let twoWeeks = sut.weekdayAverageCount(from: events, periodDays: 14)
        #expect(twoWeeks.count == 7)
        #expect(twoWeeks[todayWeekday].avg == 2.0)
        #expect(twoWeeks.filter { $0.weekday != todayWeekday }.allSatisfy { $0.avg == 0 })

        let short = sut.weekdayAverageCount(from: events, periodDays: 3)
        #expect(short[todayWeekday].avg == 4.0)   // max(1, 3/7) = 1주
    }

    @Test("요일 평균(DozyEvent): 비반복은 시작 요일만, 매일 반복은 기간 내 모든 날을 전개한다")
    func 요일평균_도지_반복전개() {
        let periodStart = date(daysAgo: 6, hour: 0)

        let single = sut.weekdayAverageCount(from: [dozy(daysAgo: 3)], periodStart: periodStart, periodDays: 7)
        let singleWeekday = cal.component(.weekday, from: date(daysAgo: 3)) - 1
        #expect(single[singleWeekday].avg == 1.0)
        #expect(single.map(\.avg).reduce(0, +) == 1.0)

        let daily = sut.weekdayAverageCount(from: [dozy(daysAgo: 6, rule: "daily")], periodStart: periodStart, periodDays: 7)
        #expect(daily.allSatisfy { $0.avg == 1.0 })   // 7일 동안 매일 1건 → 모든 요일 1.0
    }

    @Test("요일 평균(DozyEvent): 반복 일정의 제외 날짜는 전개에서 빠진다")
    func 요일평균_도지_제외날짜() {
        let event = dozy(daysAgo: 6, rule: "daily")
        event.excludedDates = [today]
        let result = sut.weekdayAverageCount(from: [event], periodStart: date(daysAgo: 6, hour: 0), periodDays: 7)
        #expect(result[todayWeekday].avg == 0)
        #expect(result.map(\.avg).reduce(0, +) == 6.0)
    }

    @Test("반복 비율: recurrenceRule 이 none 이 아니면 반복으로 센다")
    func 반복비율() {
        let ratio = sut.recurrenceRatio(from: [dozy(rule: "daily"), dozy(rule: "weekly"), dozy()])
        #expect(ratio.recurring == 2)
        #expect(ratio.oneTime == 1)
    }

    // MARK: - WorkLog

    @Test("카테고리 분포: '일반'과 빈 값은 제외하고 빈도 내림차순")
    func 카테고리분포() {
        let logs = [log(category: "개발"), log(category: "회의"), log(category: "개발"), log(category: "일반"), log(category: "")]
        let dist = sut.categoryDistribution(from: logs)
        #expect(dist.map(\.category) == ["개발", "회의"])
        #expect(dist.map(\.count) == [2, 1])
    }

    @Test("생산성 점수: nil 은 제외하고 날짜 오름차순")
    func 생산성점수_정렬() {
        let logs = [log(daysAgo: 0, score: 0.9), log(daysAgo: 2, score: nil), log(daysAgo: 5, score: 0.4)]
        let scores = sut.productivityScores(from: logs)
        #expect(scores.map(\.score) == [0.4, 0.9])
        #expect(scores.map(\.date) == [date(daysAgo: 5, hour: 0), today])
    }

    @Test("평균 생산성: 점수가 하나도 없으면 nil, 있으면 평균")
    func 평균생산성() {
        #expect(sut.averageProductivityScore(from: [log(score: nil)]) == nil)
        #expect(sut.averageProductivityScore(from: [log(score: 0.2), log(score: 0.6)]) == 0.4)
    }

    // MARK: - 인사이트 문구

    private func icons(_ insights: [InsightMessage]) -> [String] { insights.map(\.icon) }

    @Test("인사이트: 완료율 구간별로 다른 아이콘 — 80% 별, 50% 체크, 25% 경고, 0% 없음")
    func 인사이트_완료율구간() {
        let high = sut.generateInsights(allCalendarEvents: [], dozyEvents: [dozy(completed: true), dozy(completed: true), dozy(completed: true), dozy(completed: true), dozy()], logs: [])
        #expect(icons(high).contains("star.fill"))
        #expect(high.first { $0.icon == "star.fill" }?.text.contains("80%") == true)

        let mid = sut.generateInsights(allCalendarEvents: [], dozyEvents: [dozy(completed: true), dozy()], logs: [])
        #expect(icons(mid).contains("checkmark.circle"))

        let low = sut.generateInsights(allCalendarEvents: [], dozyEvents: [dozy(completed: true), dozy(), dozy(), dozy()], logs: [])
        #expect(icons(low).contains("exclamationmark.circle"))

        let none = sut.generateInsights(allCalendarEvents: [], dozyEvents: [dozy()], logs: [])
        #expect(!icons(none).contains("star.fill") && !icons(none).contains("checkmark.circle") && !icons(none).contains("exclamationmark.circle"))
    }

    @Test("인사이트: 기간 라벨 — 7일은 '이번 주', 30일은 '이번 달', 그 이상은 '최근 3개월'")
    func 인사이트_기간라벨() {
        let events = [dozy(completed: true)]
        func text(_ days: Int) -> String {
            sut.generateInsights(allCalendarEvents: [], dozyEvents: events, logs: [], periodDays: days)
                .first { $0.icon == "star.fill" }!.text
        }
        #expect(text(7).hasPrefix("이번 주"))
        #expect(text(30).hasPrefix("이번 달"))
        #expect(text(90).hasPrefix("최근 3개월"))
    }

    @Test("인사이트: 스트릭 7일 이상은 flame.fill, 3일 이상은 flame, 2일은 없음")
    func 인사이트_스트릭() {
        func events(days: Int) -> [DozyEvent] { (0..<days).map { dozy(daysAgo: $0, completed: true) } }
        #expect(icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: events(days: 7), logs: [])).contains("flame.fill"))
        let three = icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: events(days: 3), logs: []))
        #expect(three.contains("flame") && !three.contains("flame.fill"))
        let two = icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: events(days: 2), logs: []))
        #expect(!two.contains("flame") && !two.contains("flame.fill"))
    }

    @Test("인사이트: 반복 일정이 70% 이상일 때만 루틴 문구")
    func 인사이트_반복비율() {
        let routine = [dozy(rule: "daily"), dozy(rule: "daily"), dozy(rule: "weekly"), dozy()]   // 75%
        #expect(icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: routine, logs: [])).contains("arrow.trianglehead.clockwise"))
        let mixed = [dozy(rule: "daily"), dozy()]   // 50%
        #expect(!icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: mixed, logs: [])).contains("arrow.trianglehead.clockwise"))
    }

    @Test("인사이트: 최근 3개 점수 평균이 이전보다 0.1 넘게 높으면 상승, 낮으면 하락")
    func 인사이트_점수추세() {
        let up = [log(daysAgo: 4, score: 0.3), log(daysAgo: 3, score: 0.3), log(daysAgo: 2, score: 0.8), log(daysAgo: 1, score: 0.9), log(daysAgo: 0, score: 0.9)]
        #expect(icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: [], logs: up)).contains("arrow.up.right.circle.fill"))
        let down = [log(daysAgo: 4, score: 0.9), log(daysAgo: 3, score: 0.9), log(daysAgo: 2, score: 0.3), log(daysAgo: 1, score: 0.3), log(daysAgo: 0, score: 0.3)]
        #expect(icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: [], logs: down)).contains("arrow.down.right.circle"))
        let flat = [log(daysAgo: 1, score: 0.5), log(daysAgo: 0, score: 0.55)]
        let flatIcons = icons(sut.generateInsights(allCalendarEvents: [], dozyEvents: [], logs: flat))
        #expect(!flatIcons.contains("arrow.up.right.circle.fill") && !flatIcons.contains("arrow.down.right.circle"))
    }

    @Test("인사이트: 7일 기간은 하루 평균 일정 수 문구")
    func 인사이트_주간평균() {
        let result = sut.generateInsights(allCalendarEvents: [calendarEvent(), calendarEvent(daysAgo: 1)], dozyEvents: [], logs: [], periodDays: 7)
        #expect(result.first { $0.icon == "number" }?.text.contains("0.3") == true)   // 2/7 ≈ 0.29 → "0.3"
    }

    @Test("인사이트: 30일 기간은 전·후반 차이가 3건 이상일 때만 비교 문구")
    func 인사이트_월간전후반() {
        let bigGap = [calendarEvent(daysAgo: 20)] + (0..<5).map { _ in calendarEvent(daysAgo: 2) }
        #expect(icons(sut.generateInsights(allCalendarEvents: bigGap, dozyEvents: [], logs: [], periodDays: 30)).contains("arrow.left.arrow.right"))
        let smallGap = [calendarEvent(daysAgo: 20), calendarEvent(daysAgo: 2), calendarEvent(daysAgo: 2)]
        #expect(!icons(sut.generateInsights(allCalendarEvents: smallGap, dozyEvents: [], logs: [], periodDays: 30)).contains("arrow.left.arrow.right"))
    }

    @Test("인사이트: 90일 기간은 세 달 모두 일정이 있을 때 첫 달 대비 증감 문구")
    func 인사이트_3개월추세() {
        let up = [calendarEvent(daysAgo: 70), calendarEvent(daysAgo: 45)] + (0..<3).map { _ in calendarEvent(daysAgo: 5) }
        #expect(icons(sut.generateInsights(allCalendarEvents: up, dozyEvents: [], logs: [], periodDays: 90)).contains("chart.line.uptrend.xyaxis"))
        let missingMonth = [calendarEvent(daysAgo: 70), calendarEvent(daysAgo: 5)]   // 둘째 달 없음
        let result = icons(sut.generateInsights(allCalendarEvents: missingMonth, dozyEvents: [], logs: [], periodDays: 90))
        #expect(!result.contains("chart.line.uptrend.xyaxis") && !result.contains("chart.line.downtrend.xyaxis"))
    }
}
