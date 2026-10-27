//
//  EveningCheckPromptTests.swift
//  Dozy AITests
//
//  저녁 일정 체크 프롬프트의 노출 조건(EveningCheckPrompt)과 대상 일정 필터. "지금"을 주입해 어느 날 돌려도 같다.
//  makeTestEvent 는 2026-04-11 의 시간대별 일정을 만들므로, now 도 같은 날로 잡는다.
//

import Testing
import Foundation
@testable import Dozy_AI

@Suite("EveningCheckPrompt")
@MainActor
struct EveningCheckPromptTests {

    private let cal = Calendar.current

    /// 2026-04-11 hour:minute
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 4, day: 11, hour: hour, minute: minute))!
    }

    // MARK: - 시간대

    @Test("18:00 부터 자정 전까지가 노출 시간대")
    func window() {
        #expect(!EveningCheckPrompt.isInWindow(at(17, 59), calendar: cal))
        #expect(EveningCheckPrompt.isInWindow(at(18, 0), calendar: cal))
        #expect(EveningCheckPrompt.isInWindow(at(23, 59), calendar: cal))
        #expect(!EveningCheckPrompt.isInWindow(at(0, 10), calendar: cal))
    }

    // MARK: - 대상 일정

    @Test("완료된 일정, 공휴일, 아직 안 끝난 시간제 일정은 빠지고 끝난 일정·종일 일정만 남는다")
    func targetEventsFilter() {
        let ended = makeTestEvent(title: "끝남", startHour: 9, endHour: 10)
        let endedButChecked = makeTestEvent(title: "끝났고 체크됨", startHour: 11, endHour: 12)
        let upcoming = makeTestEvent(title: "아직", startHour: 21, endHour: 22)
        let allDay = makeTestEvent(title: "종일", startHour: 0, endHour: 23, isAllDay: true)
        let holiday = makeTestEvent(title: "공휴일", startHour: 0, endHour: 23, isAllDay: true, source: .holiday)

        let targets = EveningCheckPrompt.targetEvents(
            [upcoming, endedButChecked, holiday, ended, allDay],
            completions: [endedButChecked.id: true, ended.id: false],
            now: at(19)
        )
        #expect(targets.map(\.title) == ["종일", "끝남"])
    }

    @Test("종료 시각이 지금과 같으면 끝난 것으로 본다")
    func targetEventsEndBoundary() {
        let event = makeTestEvent(startHour: 18, endHour: 19)
        #expect(EveningCheckPrompt.targetEvents([event], completions: [:], now: at(19)).count == 1)
        #expect(EveningCheckPrompt.targetEvents([event], completions: [:], now: at(18, 59)).isEmpty)
    }

    // MARK: - 노출 조건

    @Test("시간대 안 · 켜짐 · 오늘 미표시 · 대상 있음 → 표시")
    func shouldPromptHappyPath() {
        #expect(EveningCheckPrompt.shouldPrompt(now: at(19), isEnabled: true, lastShownDay: nil, targetCount: 2, calendar: cal))
        #expect(EveningCheckPrompt.shouldPrompt(now: at(19), isEnabled: true, lastShownDay: "2026-04-10", targetCount: 1, calendar: cal))
    }

    @Test("꺼짐 · 대상 없음 · 시간대 밖 · 오늘 이미 표시 → 각각 표시하지 않음")
    func shouldPromptNegatives() {
        #expect(!EveningCheckPrompt.shouldPrompt(now: at(19), isEnabled: false, lastShownDay: nil, targetCount: 2, calendar: cal))
        #expect(!EveningCheckPrompt.shouldPrompt(now: at(19), isEnabled: true, lastShownDay: nil, targetCount: 0, calendar: cal))
        #expect(!EveningCheckPrompt.shouldPrompt(now: at(12), isEnabled: true, lastShownDay: nil, targetCount: 2, calendar: cal))
        #expect(!EveningCheckPrompt.shouldPrompt(now: at(19), isEnabled: true, lastShownDay: "2026-04-11", targetCount: 2, calendar: cal))
    }

    // MARK: - 저장

    @Test("기본값은 켜짐이고, 표시 기록은 날짜 키로 남는다")
    func store() {
        let suite = "test.eveningCheck.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(EveningCheckPrompt.Store.isEnabled(defaults: defaults))
        defaults.set(false, forKey: EveningCheckPrompt.enabledKey)
        #expect(!EveningCheckPrompt.Store.isEnabled(defaults: defaults))

        #expect(EveningCheckPrompt.Store.lastShownDay(defaults: defaults) == nil)
        EveningCheckPrompt.Store.markShown(on: at(19), calendar: cal, defaults: defaults)
        #expect(EveningCheckPrompt.Store.lastShownDay(defaults: defaults) == "2026-04-11")
    }
}
