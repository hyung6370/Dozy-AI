//
//  SummaryReminderScheduleTests.swift
//  Dozy AITests
//
//  저녁 요약 알림의 날짜별 스케줄 계산(SummaryReminderSchedule)과 설정(SummaryReminderSettings)의 순수 로직.
//  "지금"을 주입해 어느 날 돌려도 같은 결과가 나오게 한다. UserNotifications 는 건드리지 않는다.
//

import Testing
import Foundation
@testable import Dozy_AI

@Suite("SummaryReminderSchedule")
@MainActor
struct SummaryReminderScheduleTests {

    private let cal = Calendar.current
    private let settings = SummaryReminderSettings(isEnabled: true, hour: 21, minute: 0)

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - preGenerationDate (macOS 포그라운드 미리 생성)

    @Test("알림 10분 전이 아직 안 왔으면 그 시각")
    func preGenerationBeforeWindow() {
        let now = date(2026, 3, 5, 10)
        #expect(SummaryReminderSchedule.preGenerationDate(settings: settings, from: now, calendar: cal) == date(2026, 3, 5, 20, 50))
    }

    @Test("10분 창 안에 들어와 있으면 지금 바로")
    func preGenerationInsideWindow() {
        let now = date(2026, 3, 5, 20, 55)
        #expect(SummaryReminderSchedule.preGenerationDate(settings: settings, from: now, calendar: cal) == now)
    }

    @Test("오늘 알림 시각이 지났으면 내일 10분 전")
    func preGenerationAfterFire() {
        let now = date(2026, 3, 5, 21, 30)
        #expect(SummaryReminderSchedule.preGenerationDate(settings: settings, from: now, calendar: cal) == date(2026, 3, 6, 20, 50))
    }

    // MARK: - shouldPreGenerate (오늘 알림이 남아 있을 때만)

    @Test("오늘 알림 시각 전이면 미리 생성한다")
    func shouldPreGenerateBeforeFire() {
        #expect(SummaryReminderSchedule.shouldPreGenerate(settings: settings, now: date(2026, 3, 5, 20, 55), calendar: cal))
    }

    @Test("오늘 알림 시각이 지났으면 내일 알림에 오늘 수치가 들어가므로 생략")
    func shouldNotPreGenerateAfterFire() {
        #expect(!SummaryReminderSchedule.shouldPreGenerate(settings: settings, now: date(2026, 3, 5, 21, 1), calendar: cal))
    }

    @Test("자정 직후는 그날 알림 전이라 생성, 자정 직전은 그날 알림이 지나 생략")
    func shouldPreGenerateAroundMidnight() {
        #expect(SummaryReminderSchedule.shouldPreGenerate(settings: settings, now: date(2026, 3, 6, 0, 1), calendar: cal))
        #expect(!SummaryReminderSchedule.shouldPreGenerate(settings: settings, now: date(2026, 3, 5, 23, 59), calendar: cal))
    }

    @Test("꺼져 있으면 항상 생략")
    func shouldNotPreGenerateWhenDisabled() {
        let off = SummaryReminderSettings(isEnabled: false, hour: 21, minute: 0)
        #expect(!SummaryReminderSchedule.shouldPreGenerate(settings: off, now: date(2026, 3, 5, 10), calendar: cal))
    }

    // MARK: - nextFireDate

    @Test("오늘 시각이 아직 안 지났으면 오늘, 지났으면 내일")
    func nextFireDate() {
        let before = date(2026, 3, 5, 10)
        let after = date(2026, 3, 5, 21, 30)
        #expect(settings.nextFireDate(after: before, calendar: cal) == date(2026, 3, 5, 21))
        #expect(settings.nextFireDate(after: after, calendar: cal) == date(2026, 3, 6, 21))
    }

    // MARK: - upcomingSlots

    @Test("시각 전이면 오늘부터 7일치, 첫 슬롯은 오늘 21:00")
    func slotsBeforeTime() {
        let slots = SummaryReminderSchedule.upcomingSlots(settings: settings, from: date(2026, 3, 5, 10), calendar: cal)
        #expect(slots.count == 7)
        #expect(slots.first?.fireDate == date(2026, 3, 5, 21))
        #expect(slots.first?.dayKey == "2026-03-05")
        #expect(slots.last?.dayKey == "2026-03-11")
    }

    @Test("시각이 지났으면 오늘은 빠지고 내일부터 6일치")
    func slotsAfterTime() {
        let slots = SummaryReminderSchedule.upcomingSlots(settings: settings, from: date(2026, 3, 5, 21, 30), calendar: cal)
        #expect(slots.count == 6)
        #expect(slots.first?.dayKey == "2026-03-06")
    }

    @Test("슬롯의 트리거 컴포넌트는 해당 날짜 + 설정 시각")
    func slotComponents() {
        let slot = SummaryReminderSchedule.upcomingSlots(settings: settings, from: date(2026, 3, 5, 10), calendar: cal)[2]
        #expect(slot.components.year == 2026)
        #expect(slot.components.month == 3)
        #expect(slot.components.day == 7)
        #expect(slot.components.hour == 21)
        #expect(slot.components.minute == 0)
    }

    @Test("식별자는 접두사 + 날짜 키이며 서로 겹치지 않는다")
    func identifiers() {
        let slots = SummaryReminderSchedule.upcomingSlots(settings: settings, from: date(2026, 3, 5, 10), calendar: cal)
        let ids = slots.map(\.identifier)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy(SummaryReminderSchedule.isReminderIdentifier))
        #expect(ids.first == "dozy.summaryReminder.2026-03-05")
    }

    @Test("예전 반복 요청 식별자도 요약 알림으로 인식해 정리 대상이 된다")
    func legacyIdentifierRecognised() {
        #expect(SummaryReminderSchedule.isReminderIdentifier("dozy.summaryReminder"))
        #expect(!SummaryReminderSchedule.isReminderIdentifier("dozy.eventReminder.123"))
    }

    @Test("날짜 키는 yyyy-MM-dd 로 0 패딩된다")
    func dayKeyFormat() {
        #expect(SummaryReminderSchedule.dayKey(for: date(2026, 3, 5, 10), calendar: cal) == "2026-03-05")
        #expect(SummaryReminderSchedule.dayKey(for: date(2026, 12, 25, 23, 59), calendar: cal) == "2026-12-25")
    }

    // MARK: - desiredSlots / plan

    @Test("오늘 요약을 이미 봤으면 오늘 슬롯이 빠진다")
    func desiredSlotsSkipsViewedToday() {
        let now = date(2026, 3, 5, 10)
        let all = SummaryReminderSchedule.desiredSlots(settings: settings, from: now, viewedToday: false, calendar: cal)
        let viewed = SummaryReminderSchedule.desiredSlots(settings: settings, from: now, viewedToday: true, calendar: cal)
        #expect(all.count == 7)
        #expect(viewed.count == 6)
        #expect(viewed.first?.dayKey == "2026-03-06")
    }

    @Test("대기 요청이 없으면 전부 추가, 지울 것 없음")
    func planFromEmpty() {
        let slots = SummaryReminderSchedule.upcomingSlots(settings: settings, from: date(2026, 3, 5, 10), calendar: cal)
        let plan = SummaryReminderSchedule.plan(desired: slots, pending: [])
        #expect(plan.add.count == 7)
        #expect(plan.remove.isEmpty)
    }

    @Test("이미 7일치가 있으면 아무것도 추가·삭제하지 않는다 (멱등)")
    func planIsIdempotent() {
        let slots = SummaryReminderSchedule.upcomingSlots(settings: settings, from: date(2026, 3, 5, 10), calendar: cal)
        let plan = SummaryReminderSchedule.plan(desired: slots, pending: Set(slots.map(\.identifier)))
        #expect(plan.add.isEmpty)
        #expect(plan.remove.isEmpty)
    }

    @Test("하루 지나면 새 날 하나만 추가되고, 예전 반복 요청·지난 날·오늘 본 날은 정리된다")
    func planRollsForwardAndCleansUp() {
        let yesterdaySlots = SummaryReminderSchedule.upcomingSlots(settings: settings, from: date(2026, 3, 4, 10), calendar: cal)
        var pending = Set(yesterdaySlots.map(\.identifier))        // 03-04 ... 03-10
        pending.insert("dozy.summaryReminder")                       // 업그레이드 전 반복 요청

        // 오늘(03-05) 10시, 오늘 요약은 이미 봄 → 03-06 ... 03-11 이 바람직한 상태
        let desired = SummaryReminderSchedule.desiredSlots(settings: settings, from: date(2026, 3, 5, 10), viewedToday: true, calendar: cal)
        let plan = SummaryReminderSchedule.plan(desired: desired, pending: pending)

        #expect(plan.add.map(\.dayKey) == ["2026-03-11"])
        #expect(plan.remove == ["dozy.summaryReminder", "dozy.summaryReminder.2026-03-04", "dozy.summaryReminder.2026-03-05"])
    }

    // MARK: - 수치 본문

    @Test("수치 본문에 완료 건수와 백분율 점수가 들어간다")
    func numericBody() {
        let body = SummaryReminderSchedule.numericBody(completedEventCount: 3, productivityScore: 0.824)
        #expect(body.contains("3"))
        #expect(body.contains("82"))
    }

    // MARK: - 확인 기록

    @Test("오늘 확인을 기록하면 오늘만 true, 다른 날은 false")
    func viewedStore() {
        let suite = "test.summaryReminder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let today = date(2026, 3, 5, 10)
        #expect(!SummaryReminderViewedStore.hasViewed(on: today, calendar: cal, defaults: defaults))

        SummaryReminderViewedStore.markViewed(on: today, calendar: cal, defaults: defaults)
        #expect(SummaryReminderViewedStore.hasViewed(on: today, calendar: cal, defaults: defaults))
        #expect(SummaryReminderViewedStore.hasViewed(on: date(2026, 3, 5, 23, 59), calendar: cal, defaults: defaults))
        #expect(!SummaryReminderViewedStore.hasViewed(on: date(2026, 3, 6, 0, 1), calendar: cal, defaults: defaults))
    }
}
