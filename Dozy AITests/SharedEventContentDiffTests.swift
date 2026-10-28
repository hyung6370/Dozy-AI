//
//  SharedEventContentDiffTests.swift
//  Dozy AITests
//
//  공유 캘린더 Realtime 이 로컬 DozyEvent 와 원격 row 의 내용을 비교해 "같으면 저장 · 알림 생략" 하는
//  순수 비교(SharedEventContentDiff.isSame) 를 고정한다 (#110 · #112). 필드 하나만 달라도 false 여야
//  파트너 변경이 묻히지 않고, 전부 같으면 true 여야 초기 fetch 가 알림을 쏟지 않는다.
//

import Testing
import Foundation
@testable import Dozy_AI

@Suite("SharedEventContentDiff")
@MainActor
struct SharedEventContentDiffTests {

    private let start = Date(timeIntervalSince1970: 1_775_000_000)
    private let synced = Date(timeIntervalSince1970: 1_775_100_000)

    private func makeEvent() -> DozyEvent {
        let e = DozyEvent(
            id: "evt-1", title: "치과", startDate: start, endDate: start.addingTimeInterval(1800),
            isAllDay: false, location: "강남", latitude: 37.5, longitude: 127.0, notes: "메모",
            colorHex: "#FF0000", recurrenceRule: "weekly", recurrenceEndDate: start.addingTimeInterval(86_400 * 30),
            notificationMinutesBefore: 10, priority: 2, isPinned: true, category: "건강",
            sharedCalendarID: "cal-1", ownerID: "user-1",
            externalSource: "apple", externalEventID: "ext-1", externalLastSyncedAt: synced, externalDeleted: false
        )
        e.memos = ["a", "b"]
        e.isCompleted = true
        return e
    }

    /// 이벤트와 같은 내용의 row. 바꿀 필드만 클로저로 덮어쓴다.
    private func makeRow(_ e: DozyEvent, _ mutate: (inout SharedEventRow) -> Void = { _ in }) -> SharedEventRow {
        var row = SharedEventRow(
            id: e.id, userID: e.ownerID ?? "", title: e.title, startDate: e.startDate, endDate: e.endDate,
            isAllDay: e.isAllDay, location: e.location, latitude: e.latitude, longitude: e.longitude,
            notes: e.notes, colorHex: e.colorHex, recurrenceRule: e.recurrenceRule,
            recurrenceEndDate: e.recurrenceEndDate, notificationMinutesBefore: e.notificationMinutesBefore,
            memos: e.memos, isCompleted: e.isCompleted, priority: e.priority, isPinned: e.isPinned,
            category: e.category, sharedCalendarID: e.sharedCalendarID,
            externalSource: e.externalSource, externalEventID: e.externalEventID,
            externalLastSyncedAt: e.externalLastSyncedAt, externalDeleted: e.externalDeleted
        )
        mutate(&row)
        return row
    }

    @Test("내용이 전부 같으면 true — 초기 fetch 가 알림을 쏟지 않는 전제")
    func sameContent() {
        let e = makeEvent()
        #expect(SharedEventContentDiff.isSame(e, makeRow(e)))
    }

    @Test("ownerID · sharedCalendarID 는 덮어쓰지 않으므로 달라도 같다고 본다")
    func ignoresOwnerAndCalendar() {
        let e = makeEvent()
        let row = makeRow(e) { $0 = SharedEventRow(
            id: $0.id, userID: "someone-else", title: $0.title, startDate: $0.startDate, endDate: $0.endDate,
            isAllDay: $0.isAllDay, location: $0.location, latitude: $0.latitude, longitude: $0.longitude,
            notes: $0.notes, colorHex: $0.colorHex, recurrenceRule: $0.recurrenceRule,
            recurrenceEndDate: $0.recurrenceEndDate, notificationMinutesBefore: $0.notificationMinutesBefore,
            memos: $0.memos, isCompleted: $0.isCompleted, priority: $0.priority, isPinned: $0.isPinned,
            category: $0.category, sharedCalendarID: "other-cal",
            externalSource: $0.externalSource, externalEventID: $0.externalEventID,
            externalLastSyncedAt: $0.externalLastSyncedAt, externalDeleted: $0.externalDeleted) }
        #expect(SharedEventContentDiff.isSame(e, row))
    }

    @Test("제목 · 시작 · 완료 · 메모 · 외부 삭제 플래그 하나만 달라도 false",
          arguments: ["title", "startDate", "isCompleted", "memos", "externalDeleted", "priority", "category"])
    func singleFieldDiffers(field: String) {
        let e = makeEvent()
        let base = makeRow(e)
        let row = SharedEventRow(
            id: base.id, userID: base.userID,
            title: field == "title" ? "치과 (변경)" : base.title,
            startDate: field == "startDate" ? base.startDate.addingTimeInterval(60) : base.startDate,
            endDate: base.endDate, isAllDay: base.isAllDay, location: base.location,
            latitude: base.latitude, longitude: base.longitude, notes: base.notes, colorHex: base.colorHex,
            recurrenceRule: base.recurrenceRule, recurrenceEndDate: base.recurrenceEndDate,
            notificationMinutesBefore: base.notificationMinutesBefore,
            memos: field == "memos" ? ["a"] : base.memos,
            isCompleted: field == "isCompleted" ? !base.isCompleted : base.isCompleted,
            priority: field == "priority" ? 5 : base.priority,
            isPinned: base.isPinned,
            category: field == "category" ? "업무" : base.category,
            sharedCalendarID: base.sharedCalendarID, externalSource: base.externalSource,
            externalEventID: base.externalEventID, externalLastSyncedAt: base.externalLastSyncedAt,
            externalDeleted: field == "externalDeleted" ? !base.externalDeleted : base.externalDeleted
        )
        #expect(!SharedEventContentDiff.isSame(e, row), "\(field) 가 다르면 변경으로 봐야 한다")
    }

    @Test("옵셔널은 nil 과 빈 문자열을 구분한다 (location nil ↔ \"\")")
    func optionalNilVersusEmpty() {
        let e = makeEvent()
        e.location = nil
        let sameNil = makeRow(e)
        #expect(SharedEventContentDiff.isSame(e, sameNil))
        let empty = SharedEventRow(
            id: sameNil.id, userID: sameNil.userID, title: sameNil.title, startDate: sameNil.startDate,
            endDate: sameNil.endDate, isAllDay: sameNil.isAllDay, location: "",
            latitude: sameNil.latitude, longitude: sameNil.longitude, notes: sameNil.notes,
            colorHex: sameNil.colorHex, recurrenceRule: sameNil.recurrenceRule,
            recurrenceEndDate: sameNil.recurrenceEndDate, notificationMinutesBefore: sameNil.notificationMinutesBefore,
            memos: sameNil.memos, isCompleted: sameNil.isCompleted, priority: sameNil.priority,
            isPinned: sameNil.isPinned, category: sameNil.category, sharedCalendarID: sameNil.sharedCalendarID,
            externalSource: sameNil.externalSource, externalEventID: sameNil.externalEventID,
            externalLastSyncedAt: sameNil.externalLastSyncedAt, externalDeleted: sameNil.externalDeleted
        )
        #expect(!SharedEventContentDiff.isSame(e, empty))
    }

    @Test("외부 동기화 시각이 1초만 달라도 false")
    func externalSyncTimeDiffers() {
        let e = makeEvent()
        let base = makeRow(e)
        let row = SharedEventRow(
            id: base.id, userID: base.userID, title: base.title, startDate: base.startDate, endDate: base.endDate,
            isAllDay: base.isAllDay, location: base.location, latitude: base.latitude, longitude: base.longitude,
            notes: base.notes, colorHex: base.colorHex, recurrenceRule: base.recurrenceRule,
            recurrenceEndDate: base.recurrenceEndDate, notificationMinutesBefore: base.notificationMinutesBefore,
            memos: base.memos, isCompleted: base.isCompleted, priority: base.priority, isPinned: base.isPinned,
            category: base.category, sharedCalendarID: base.sharedCalendarID, externalSource: base.externalSource,
            externalEventID: base.externalEventID, externalLastSyncedAt: synced.addingTimeInterval(1),
            externalDeleted: base.externalDeleted
        )
        #expect(!SharedEventContentDiff.isSame(e, row))
    }
}
