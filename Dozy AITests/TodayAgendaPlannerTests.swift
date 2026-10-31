//
//  TodayAgendaPlannerTests.swift
//  Dozy AITests
//
//  "오늘 아젠다" Live Activity 플래너의 순수 계산 검증 — current/next 선정, 완료·종일 제외,
//  staleDate, 마지막 일정의 예약 종료(isFinal), 설정 끔 시 종료.
//

import XCTest
@testable import Dozy_AI

@MainActor
final class TodayAgendaPlannerTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date!

    override func setUp() async throws {
        try await super.setUp()
        // 오늘 10:00 고정 — 날짜 경계와 무관하게 상대 시각으로 조립한다.
        now = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())
    }

    private func item(
        _ id: String,
        startHour: Int, startMinute: Int = 0,
        endHour: Int, endMinute: Int = 0,
        isAllDay: Bool = false,
        isCompleted: Bool = false
    ) -> TodayAgendaItem {
        let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: now)!
        let end = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: now)!
        return TodayAgendaItem(id: id, title: id, start: start, end: end, isAllDay: isAllDay, isCompleted: isCompleted, colorHex: "#000000")
    }

    private func snapshot(_ plan: TodayAgendaPlan, file: StaticString = #filePath, line: UInt = #line) -> TodayAgendaSnapshot? {
        guard case .show(let s) = plan else {
            XCTFail("show 를 기대했으나 \(plan)", file: file, line: line)
            return nil
        }
        return s
    }

    // MARK: - 종료 조건

    func test_noItems_ends() {
        XCTAssertEqual(TodayAgendaPlanner.plan(items: [], now: now), .end)
    }

    func test_onlyAllDay_ends() {
        let plan = TodayAgendaPlanner.plan(items: [item("종일", startHour: 0, endHour: 23, isAllDay: true)], now: now)
        XCTAssertEqual(plan, .end)
    }

    func test_allPast_ends() {
        let plan = TodayAgendaPlanner.plan(items: [item("아침", startHour: 7, endHour: 8)], now: now)
        XCTAssertEqual(plan, .end)
    }

    func test_allCompleted_ends() {
        let items = [
            item("A", startHour: 9, endHour: 11, isCompleted: true),
            item("B", startHour: 14, endHour: 15, isCompleted: true),
        ]
        XCTAssertEqual(TodayAgendaPlanner.plan(items: items, now: now), .end)
    }

    // MARK: - current / next

    func test_currentAndNext() {
        let items = [
            item("아침", startHour: 7, endHour: 8),
            item("회의", startHour: 9, startMinute: 30, endHour: 11),
            item("점심", startHour: 12, endHour: 13),
            item("운동", startHour: 18, endHour: 19),
        ]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertEqual(s.current?.id, "회의")
        XCTAssertEqual(s.next?.id, "점심")
        XCTAssertEqual(s.remainingCount, 3, "진행 중 + 아직 안 끝난 일정")
        XCTAssertEqual(s.totalCount, 4)
        XCTAssertEqual(s.completedCount, 0)
        XCTAssertEqual(s.staleDate, s.current?.end, "current 종료(11:00)가 next 시작(12:00)보다 먼저")
        XCTAssertFalse(s.isFinal)
        XCTAssertNil(s.dismissalDate)
    }

    func test_gapBeforeNext_currentNil() {
        let items = [item("오후", startHour: 14, endHour: 15)]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertNil(s.current)
        XCTAssertEqual(s.next?.id, "오후")
        XCTAssertEqual(s.staleDate, s.next?.start)
        XCTAssertFalse(s.isFinal, "아직 시작 전이면 앱이 다시 돌 때 current 로 바꿔야 하므로 final 아님")
    }

    func test_completedCurrentIsSkipped() {
        let items = [
            item("회의", startHour: 9, endHour: 11, isCompleted: true),
            item("점심", startHour: 12, endHour: 13),
        ]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertNil(s.current, "일찍 완료한 일정은 진행 중으로 보지 않는다")
        XCTAssertEqual(s.next?.id, "점심")
        XCTAssertEqual(s.completedCount, 1)
        XCTAssertEqual(s.remainingCount, 1)
    }

    func test_overlapping_picksEarliestStart() {
        let items = [
            item("B", startHour: 9, startMinute: 45, endHour: 11),
            item("A", startHour: 9, endHour: 10, endMinute: 30),
        ]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertEqual(s.current?.id, "A")
        XCTAssertNil(s.next, "둘 다 이미 시작했으므로 next 없음")
    }

    func test_allDayIsIgnoredButTimedCounted() {
        let items = [
            item("종일", startHour: 0, endHour: 23, isAllDay: true),
            item("회의", startHour: 9, endHour: 11),
        ]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertEqual(s.totalCount, 1)
        XCTAssertEqual(s.current?.id, "회의")
    }

    // MARK: - 마지막 일정 예약 종료

    func test_lastEventInProgress_withinFourHours_isFinal() {
        let items = [item("마지막", startHour: 9, endHour: 11)]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertTrue(s.isFinal)
        XCTAssertEqual(s.dismissalDate, s.current?.end)
    }

    func test_lastEventInProgress_longerThanFourHours_notFinal() {
        let items = [item("긴 워크숍", startHour: 9, endHour: 16)]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertFalse(s.isFinal, "ActivityKit 예약 종료 상한(4시간)을 넘기면 갱신 상태로 두고 staleDate 만 건다")
        XCTAssertEqual(s.staleDate, s.current?.end)
    }

    func test_lastEventNotStarted_notFinal() {
        let items = [item("저녁", startHour: 11, endHour: 12)]
        guard let s = snapshot(TodayAgendaPlanner.plan(items: items, now: now)) else { return }
        XCTAssertFalse(s.isFinal)
        XCTAssertNil(s.dismissalDate)
    }

    // MARK: - 설정

    func test_liveActivitySettings_defaultOn_roundTrip() {
        let defaults = UserDefaults(suiteName: "TodayAgendaPlannerTests.\(UUID().uuidString)")!
        XCTAssertTrue(LiveActivitySettings.isEnabled(defaults: defaults))
        LiveActivitySettings.setEnabled(false, defaults: defaults)
        XCTAssertFalse(LiveActivitySettings.isEnabled(defaults: defaults))
        LiveActivitySettings.setEnabled(true, defaults: defaults)
        XCTAssertTrue(LiveActivitySettings.isEnabled(defaults: defaults))
    }

    // MARK: - UseCase

    @MainActor
    func test_useCase_disabled_endsWithoutPlanning() async {
        let service = RecordingLiveActivityService()
        var loaded = false
        let useCase = SyncTodayLiveActivityUseCase(
            service: service,
            loadItems: { loaded = true; return [] },
            isEnabled: { false }
        )
        let plan = await useCase.execute(now: now)
        XCTAssertEqual(plan, .end)
        XCTAssertEqual(service.endAllCount, 1)
        XCTAssertTrue(service.applied.isEmpty)
        XCTAssertFalse(loaded, "꺼져 있으면 캐시를 읽을 필요도 없다")
    }

    @MainActor
    func test_useCase_enabled_appliesPlan() async {
        let service = RecordingLiveActivityService()
        let items = [item("회의", startHour: 9, endHour: 11)]
        let useCase = SyncTodayLiveActivityUseCase(service: service, loadItems: { items }, isEnabled: { true })
        let plan = await useCase.execute(now: now)
        XCTAssertEqual(service.applied, [plan])
        XCTAssertEqual(snapshot(plan)?.current?.id, "회의")
        XCTAssertEqual(service.endAllCount, 0)
    }
}

// MARK: - Recording mock

private final class RecordingLiveActivityService: LiveActivityServiceProtocol {
    private(set) var applied: [TodayAgendaPlan] = []
    private(set) var endAllCount = 0

    func apply(_ plan: TodayAgendaPlan) async { applied.append(plan) }
    func endAll() async { endAllCount += 1 }
}
