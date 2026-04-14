//
//  DomainModelTests.swift
//  Dozy AITests
//

import XCTest
@testable import Dozy_AI

// MARK: - WorkLog Tests

final class WorkLogTests: XCTestCase {

    // MARK: Helpers

    private func makeDate(year: Int = 2026, month: Int = 4, day: Int = 11,
                          hour: Int = 0, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    private func makeCalendarEvent(
        title: String = "테스트 이벤트",
        startHour: Int = 9, endHour: Int = 10,
        isAllDay: Bool = false, location: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString, calendarId: nil, title: title,
            startDate: makeDate(hour: startHour), endDate: makeDate(hour: endHour),
            location: location, notes: nil, isAllDay: isAllDay,
            calendarName: "테스트", calendarColorHex: "#007AFF",
            source: .apple, priority: 0, isPinned: false, category: "일반"
        )
    }

    private func makeTaskItem(title: String = "테스트 할 일") -> TaskItem {
        TaskItem(id: UUID().uuidString, title: title, isCompleted: true,
                 completedDate: Date(), dueDate: nil,
                 priority: 0, listName: "리마인더", notes: nil)
    }

    // MARK: init

    func test_init_normalizesDateToStartOfDay() {
        let noon = makeDate(hour: 12, minute: 30)
        let log = WorkLog(date: noon)
        XCTAssertEqual(log.date, noon.startOfDay)
    }

    func test_init_startsWithEmptyArrays() {
        let log = WorkLog(date: Date())
        XCTAssertTrue(log.rawEventTitles.isEmpty)
        XCTAssertTrue(log.rawEventDetails.isEmpty)
        XCTAssertTrue(log.completedTaskTitles.isEmpty)
        XCTAssertTrue(log.memos.isEmpty)
        XCTAssertTrue(log.highlights.isEmpty)
        XCTAssertTrue(log.nextActions.isEmpty)
    }

    func test_init_defaultCategory() {
        let log = WorkLog(date: Date())
        XCTAssertEqual(log.category, UserCategory.defaultName)
    }

    func test_init_productivityScoreIsNil() {
        let log = WorkLog(date: Date())
        XCTAssertNil(log.productivityScore)
    }

    func test_init_aiSummaryIsEmpty() {
        let log = WorkLog(date: Date())
        XCTAssertTrue(log.aiSummary.isEmpty)
    }

    // MARK: populate(with events:)

    func test_populateWithEvents_fillsRawTitles() {
        let log = WorkLog(date: Date())
        let events = [makeCalendarEvent(title: "팀 미팅"), makeCalendarEvent(title: "코드 리뷰")]
        log.populate(with: events)
        XCTAssertEqual(log.rawEventTitles, ["팀 미팅", "코드 리뷰"])
    }

    func test_populateWithEvents_fillsRawDetails() {
        let log = WorkLog(date: Date())
        log.populate(with: [makeCalendarEvent(title: "스탠드업")])
        XCTAssertFalse(log.rawEventDetails.isEmpty)
        XCTAssertTrue(log.rawEventDetails[0].contains("스탠드업"))
    }

    func test_populateWithEvents_emptyList_clearsExistingData() {
        let log = WorkLog(date: Date())
        log.populate(with: [makeCalendarEvent()])
        log.populate(with: [] as [CalendarEvent])
        XCTAssertTrue(log.rawEventTitles.isEmpty)
        XCTAssertTrue(log.rawEventDetails.isEmpty)
    }

    // MARK: populate(with tasks:)

    func test_populateWithTasks_fillsCompletedTitles() {
        let log = WorkLog(date: Date())
        let tasks = [makeTaskItem(title: "PR 리뷰"), makeTaskItem(title: "문서 작성")]
        log.populate(with: tasks)
        XCTAssertEqual(log.completedTaskTitles, ["PR 리뷰", "문서 작성"])
    }

    func test_populateWithTasks_emptyList_clearsTitles() {
        let log = WorkLog(date: Date())
        log.populate(with: [makeTaskItem()])
        log.populate(with: [] as [TaskItem])
        XCTAssertTrue(log.completedTaskTitles.isEmpty)
    }

    // MARK: addMemo

    func test_addMemo_appendsMemo() {
        let log = WorkLog(date: Date())
        log.addMemo("오늘 회의 내용")
        XCTAssertEqual(log.memos, ["오늘 회의 내용"])
    }

    func test_addMemo_emptyString_isIgnored() {
        let log = WorkLog(date: Date())
        log.addMemo("")
        XCTAssertTrue(log.memos.isEmpty)
    }

    func test_addMemo_whitespaceOnly_isIgnored() {
        let log = WorkLog(date: Date())
        log.addMemo("   \n   ")
        XCTAssertTrue(log.memos.isEmpty)
    }

    func test_addMemo_multipleMemos_appendsInOrder() {
        let log = WorkLog(date: Date())
        log.addMemo("메모1"); log.addMemo("메모2"); log.addMemo("메모3")
        XCTAssertEqual(log.memos, ["메모1", "메모2", "메모3"])
    }

    // MARK: updateMemo

    func test_updateMemo_validIndex_updatesText() {
        let log = WorkLog(date: Date())
        log.addMemo("원래 메모")
        log.updateMemo(at: 0, text: "수정된 메모")
        XCTAssertEqual(log.memos[0], "수정된 메모")
    }

    func test_updateMemo_trimsLeadingTrailingWhitespace() {
        let log = WorkLog(date: Date())
        log.addMemo("메모")
        log.updateMemo(at: 0, text: "  공백 포함  ")
        XCTAssertEqual(log.memos[0], "공백 포함")
    }

    func test_updateMemo_outOfBoundsIndex_doesNotCrash() {
        let log = WorkLog(date: Date())
        log.addMemo("메모")
        log.updateMemo(at: 99, text: "수정")
        XCTAssertEqual(log.memos[0], "메모")
    }

    func test_updateMemo_negativeIndex_doesNotCrash() {
        let log = WorkLog(date: Date())
        log.addMemo("메모")
        log.updateMemo(at: -1, text: "수정")
        XCTAssertEqual(log.memos[0], "메모")
    }

    func test_updateMemo_emptyText_doesNotModify() {
        let log = WorkLog(date: Date())
        log.addMemo("원래 메모")
        log.updateMemo(at: 0, text: "")
        XCTAssertEqual(log.memos[0], "원래 메모")
    }

    func test_updateMemo_whitespaceText_doesNotModify() {
        let log = WorkLog(date: Date())
        log.addMemo("원래 메모")
        log.updateMemo(at: 0, text: "   ")
        XCTAssertEqual(log.memos[0], "원래 메모")
    }

    // MARK: deleteMemo

    func test_deleteMemo_validIndex_removesMemo() {
        let log = WorkLog(date: Date())
        log.addMemo("메모1"); log.addMemo("메모2")
        log.deleteMemo(at: 0)
        XCTAssertEqual(log.memos, ["메모2"])
    }

    func test_deleteMemo_outOfBoundsIndex_doesNotCrash() {
        let log = WorkLog(date: Date())
        log.addMemo("메모")
        log.deleteMemo(at: 99)
        XCTAssertEqual(log.memos.count, 1)
    }

    func test_deleteMemo_negativeIndex_doesNotCrash() {
        let log = WorkLog(date: Date())
        log.addMemo("메모")
        log.deleteMemo(at: -1)
        XCTAssertEqual(log.memos.count, 1)
    }

    func test_deleteMemo_onlyItem_leavesEmptyArray() {
        let log = WorkLog(date: Date())
        log.addMemo("메모")
        log.deleteMemo(at: 0)
        XCTAssertTrue(log.memos.isEmpty)
    }

    // MARK: isToday

    func test_isToday_todayDate_returnsTrue() {
        XCTAssertTrue(WorkLog(date: Date()).isToday)
    }

    func test_isToday_yesterday_returnsFalse() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(WorkLog(date: yesterday).isToday)
    }

    func test_isToday_tomorrow_returnsFalse() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertFalse(WorkLog(date: tomorrow).isToday)
    }

    // MARK: fullContextString

    func test_fullContextString_noData_isEmpty() {
        XCTAssertTrue(WorkLog(date: Date()).fullContextString.isEmpty)
    }

    func test_fullContextString_withEvents_includesEventSectionHeader() {
        let log = WorkLog(date: Date())
        log.rawEventDetails = ["[오전 9:00 ~ 10:00] 스탠드업"]
        let context = log.fullContextString
        XCTAssertTrue(context.contains("## 오늘의 일정"))
        XCTAssertTrue(context.contains("스탠드업"))
    }

    func test_fullContextString_withTasks_includesCheckmarkSymbol() {
        let log = WorkLog(date: Date())
        log.completedTaskTitles = ["PR 리뷰"]
        let context = log.fullContextString
        XCTAssertTrue(context.contains("## 완료한 할 일"))
        XCTAssertTrue(context.contains("✅ PR 리뷰"))
    }

    func test_fullContextString_withMemos_includesMemoSymbol() {
        let log = WorkLog(date: Date())
        log.addMemo("중요한 메모")
        let context = log.fullContextString
        XCTAssertTrue(context.contains("## 메모"))
        XCTAssertTrue(context.contains("📝 중요한 메모"))
    }

    func test_fullContextString_allSections_allHeadersPresent() {
        let log = WorkLog(date: Date())
        log.rawEventDetails = ["이벤트"]
        log.completedTaskTitles = ["할 일"]
        log.addMemo("메모")
        let context = log.fullContextString
        XCTAssertTrue(context.contains("## 오늘의 일정"))
        XCTAssertTrue(context.contains("## 완료한 할 일"))
        XCTAssertTrue(context.contains("## 메모"))
    }

    func test_fullContextString_onlyEvents_noTaskOrMemoHeaders() {
        let log = WorkLog(date: Date())
        log.rawEventDetails = ["이벤트"]
        let context = log.fullContextString
        XCTAssertFalse(context.contains("## 완료한 할 일"))
        XCTAssertFalse(context.contains("## 메모"))
    }
}

// MARK: - CalendarEvent Tests

final class CalendarEventTests: XCTestCase {

    // MARK: Helpers

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 11
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    private func makeEvent(
        title: String = "테스트",
        startHour: Int = 14, endHour: Int = 15,
        startMinute: Int = 0, endMinute: Int = 0,
        isAllDay: Bool = false, location: String? = nil,
        category: String = "업무", priority: Int = 0, isPinned: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString, calendarId: nil, title: title,
            startDate: makeDate(hour: startHour, minute: startMinute),
            endDate: makeDate(hour: endHour, minute: endMinute),
            location: location, notes: nil, isAllDay: isAllDay,
            calendarName: "테스트 캘린더", calendarColorHex: "#007AFF",
            source: .apple, priority: priority, isPinned: isPinned, category: category
        )
    }

    // MARK: durationMinutes

    func test_durationMinutes_oneHour_returns60() {
        XCTAssertEqual(makeEvent(startHour: 14, endHour: 15).durationMinutes, 60)
    }

    func test_durationMinutes_ninetyMinutes() {
        XCTAssertEqual(makeEvent(startHour: 14, endHour: 15, endMinute: 30).durationMinutes, 90)
    }

    func test_durationMinutes_zeroDuration() {
        XCTAssertEqual(makeEvent(startHour: 14, endHour: 14).durationMinutes, 0)
    }

    // MARK: timeRangeString

    func test_timeRangeString_allDay_returns종일() {
        XCTAssertEqual(makeEvent(isAllDay: true).timeRangeString, "종일")
    }

    func test_timeRangeString_normalEvent_containsTilde() {
        XCTAssertTrue(makeEvent(isAllDay: false).timeRangeString.contains("~"))
    }

    func test_timeRangeString_notAllDay_doesNotReturn종일() {
        XCTAssertNotEqual(makeEvent(isAllDay: false).timeRangeString, "종일")
    }

    // MARK: contextString

    func test_contextString_containsTitle() {
        XCTAssertTrue(makeEvent(title: "중요한 미팅").contextString.contains("중요한 미팅"))
    }

    func test_contextString_withLocation_includesLocationLabel() {
        XCTAssertTrue(makeEvent(title: "팀 회의", location: "회의실 A").contextString.contains("장소: 회의실 A"))
    }

    func test_contextString_withNilLocation_excludesLocationLabel() {
        XCTAssertFalse(makeEvent(location: nil).contextString.contains("장소:"))
    }

    func test_contextString_withEmptyLocation_excludesLocationLabel() {
        XCTAssertFalse(makeEvent(location: "").contextString.contains("장소:"))
    }

    func test_contextString_allDay_contains종일() {
        XCTAssertTrue(makeEvent(isAllDay: true).contextString.contains("종일"))
    }

    // MARK: applying EventDisplaySettings

    func test_applying_nilSettings_returnsOriginalEvent() {
        let event = makeEvent(title: "원본", priority: 1, isPinned: false)
        let applied = event.applying(nil)
        XCTAssertEqual(applied.title, "원본")
        XCTAssertEqual(applied.priority, 1)
        XCTAssertFalse(applied.isPinned)
    }

    func test_applying_settings_updatesPriority() {
        let event = makeEvent(priority: 0)
        let applied = event.applying(EventDisplaySettings(eventID: event.id, priority: 2))
        XCTAssertEqual(applied.priority, 2)
    }

    func test_applying_settings_updatesIsPinned() {
        let event = makeEvent(isPinned: false)
        let applied = event.applying(EventDisplaySettings(eventID: event.id, isPinned: true))
        XCTAssertTrue(applied.isPinned)
    }

    func test_applying_settings_customCategory_overridesOriginal() {
        let event = makeEvent(category: "업무")
        let applied = event.applying(EventDisplaySettings(eventID: event.id, category: "개인"))
        XCTAssertEqual(applied.category, "개인")
    }

    func test_applying_settings_defaultCategory_keepsOriginalCategory() {
        let event = makeEvent(category: "업무")
        let applied = event.applying(EventDisplaySettings(eventID: event.id, category: UserCategory.defaultName))
        XCTAssertEqual(applied.category, "업무")
    }

    func test_applying_settings_preservesTitle() {
        let event = makeEvent(title: "중요 미팅")
        XCTAssertEqual(event.applying(EventDisplaySettings(eventID: event.id, priority: 1)).title, "중요 미팅")
    }

    func test_applying_settings_preservesLocation() {
        let event = makeEvent(location: "회의실 B")
        XCTAssertEqual(event.applying(EventDisplaySettings(eventID: event.id)).location, "회의실 B")
    }
}

// MARK: - DozyEvent Tests

final class DozyEventTests: XCTestCase {

    // 기준 날짜: 2026년 4월 6일 (월요일)
    private let monday: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 6
        return Calendar.current.date(from: c)!
    }()

    private func days(_ n: Int, after base: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: base)!
    }

    private func makeEvent(
        startDate: Date? = nil,
        durationDays: Int = 0,
        recurrenceRule: String = "none",
        recurrenceEndDate: Date? = nil
    ) -> DozyEvent {
        let start = startDate ?? monday
        let end = Calendar.current.date(byAdding: .day, value: durationDays, to: start)!
        return DozyEvent(title: "테스트 이벤트", startDate: start, endDate: end,
                         recurrenceRule: recurrenceRule, recurrenceEndDate: recurrenceEndDate)
    }

    // MARK: occursOn - none

    func test_occursOn_noRecurrence_onStartDate_returnsFalse() {
        XCTAssertFalse(makeEvent(recurrenceRule: "none").occursOn(monday))
    }

    func test_occursOn_noRecurrence_anyDate_returnsFalse() {
        XCTAssertFalse(makeEvent(recurrenceRule: "none").occursOn(days(7, after: monday)))
    }

    // MARK: occursOn - daily

    func test_occursOn_daily_onStartDate_returnsTrue() {
        XCTAssertTrue(makeEvent(recurrenceRule: "daily").occursOn(monday))
    }

    func test_occursOn_daily_dayAfter_returnsTrue() {
        XCTAssertTrue(makeEvent(recurrenceRule: "daily").occursOn(days(1, after: monday)))
    }

    func test_occursOn_daily_twoWeeksLater_returnsTrue() {
        XCTAssertTrue(makeEvent(recurrenceRule: "daily").occursOn(days(14, after: monday)))
    }

    func test_occursOn_daily_beforeStartDate_returnsFalse() {
        XCTAssertFalse(makeEvent(recurrenceRule: "daily").occursOn(days(-1, after: monday)))
    }

    func test_occursOn_daily_afterRecurrenceEndDate_returnsFalse() {
        let event = makeEvent(recurrenceRule: "daily", recurrenceEndDate: days(3, after: monday))
        XCTAssertFalse(event.occursOn(days(5, after: monday)))
    }

    func test_occursOn_daily_onRecurrenceEndDate_returnsTrue() {
        let endDate = days(3, after: monday)
        let event = makeEvent(recurrenceRule: "daily", recurrenceEndDate: endDate)
        XCTAssertTrue(event.occursOn(endDate))
    }

    func test_occursOn_daily_excludedDate_returnsFalse() {
        let event = makeEvent(recurrenceRule: "daily")
        let excluded = days(2, after: monday)
        event.excludedDates = [excluded]
        XCTAssertFalse(event.occursOn(excluded))
    }

    func test_occursOn_daily_nonExcludedDate_returnsTrue() {
        let event = makeEvent(recurrenceRule: "daily")
        event.excludedDates = [days(2, after: monday)]
        XCTAssertTrue(event.occursOn(days(3, after: monday)))
    }

    // MARK: occursOn - weekly

    func test_occursOn_weekly_sameWeekdayNextWeek_returnsTrue() {
        XCTAssertTrue(makeEvent(recurrenceRule: "weekly").occursOn(days(7, after: monday)))
    }

    func test_occursOn_weekly_twoWeeksLater_returnsTrue() {
        XCTAssertTrue(makeEvent(recurrenceRule: "weekly").occursOn(days(14, after: monday)))
    }

    func test_occursOn_weekly_nextDayDifferentWeekday_returnsFalse() {
        XCTAssertFalse(makeEvent(recurrenceRule: "weekly").occursOn(days(1, after: monday)))
    }

    func test_occursOn_weekly_sixDaysLater_returnsFalse() {
        XCTAssertFalse(makeEvent(recurrenceRule: "weekly").occursOn(days(6, after: monday)))
    }

    // MARK: occursOn - monthly

    func test_occursOn_monthly_sameDayNextMonth_returnsTrue() {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: monday)!
        XCTAssertTrue(makeEvent(recurrenceRule: "monthly").occursOn(nextMonth))
    }

    func test_occursOn_monthly_differentDayNextMonth_returnsFalse() {
        let differentDay = Calendar.current.date(byAdding: .day, value: 2,
            to: Calendar.current.date(byAdding: .month, value: 1, to: monday)!)!
        XCTAssertFalse(makeEvent(recurrenceRule: "monthly").occursOn(differentDay))
    }

    // MARK: occursOn - yearly

    func test_occursOn_yearly_sameDateNextYear_returnsTrue() {
        let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: monday)!
        XCTAssertTrue(makeEvent(recurrenceRule: "yearly").occursOn(nextYear))
    }

    func test_occursOn_yearly_differentDateThisYear_returnsFalse() {
        XCTAssertFalse(makeEvent(recurrenceRule: "yearly").occursOn(days(30, after: monday)))
    }

    // MARK: toCalendarEvent

    func test_toCalendarEvent_mapsTitle() {
        XCTAssertEqual(DozyEvent(title: "중요 약속", startDate: monday, endDate: monday)
            .toCalendarEvent().title, "중요 약속")
    }

    func test_toCalendarEvent_sourceIsDozy() {
        XCTAssertEqual(makeEvent().toCalendarEvent().source, .dozy)
    }

    func test_toCalendarEvent_calendarNameIsDozy() {
        XCTAssertEqual(makeEvent().toCalendarEvent().calendarName, "Dozy")
    }

    func test_toCalendarEvent_preservesLocation() {
        let event = DozyEvent(title: "회의", startDate: monday, endDate: monday, location: "회의실 A")
        XCTAssertEqual(event.toCalendarEvent().location, "회의실 A")
    }

    func test_toCalendarEvent_preservesPriorityAndPinned() {
        let event = DozyEvent(title: "회의", startDate: monday, endDate: monday,
                              priority: 2, isPinned: true)
        let calEvent = event.toCalendarEvent()
        XCTAssertEqual(calEvent.priority, 2)
        XCTAssertTrue(calEvent.isPinned)
    }

    func test_toCalendarEvent_forDate_adjustsDateOffset() {
        let event = makeEvent(recurrenceRule: "weekly")
        let targetDate = days(7, after: monday)
        let calEvent = event.toCalendarEvent(for: targetDate)
        XCTAssertEqual(Calendar.current.startOfDay(for: calEvent.startDate),
                       Calendar.current.startOfDay(for: targetDate))
    }
}

// MARK: - CalendarSource Tests

final class CalendarSourceTests: XCTestCase {

    func test_allCases_containsExactlyFour() {
        XCTAssertEqual(CalendarSource.allCases.count, 4)
    }

    func test_rawValues_matchExpected() {
        XCTAssertEqual(CalendarSource.apple.rawValue,  "apple")
        XCTAssertEqual(CalendarSource.google.rawValue, "google")
        XCTAssertEqual(CalendarSource.naver.rawValue,  "naver")
        XCTAssertEqual(CalendarSource.dozy.rawValue,   "dozy")
    }

    func test_displayNames_areNonEmpty() {
        CalendarSource.allCases.forEach {
            XCTAssertFalse($0.displayName.isEmpty, "\($0).displayName이 비어있습니다")
        }
    }

    func test_iconNames_areNonEmpty() {
        CalendarSource.allCases.forEach {
            XCTAssertFalse($0.iconName.isEmpty, "\($0).iconName이 비어있습니다")
        }
    }

    func test_displayName_apple()  { XCTAssertEqual(CalendarSource.apple.displayName,  "Apple 캘린더") }
    func test_displayName_google() { XCTAssertEqual(CalendarSource.google.displayName, "Google 캘린더") }
    func test_displayName_naver()  { XCTAssertEqual(CalendarSource.naver.displayName,  "네이버 캘린더") }
    func test_displayName_dozy()   { XCTAssertEqual(CalendarSource.dozy.displayName,   "Dozy 캘린더") }

    func test_codable_encodeDecodeRoundTrip() throws {
        for source in CalendarSource.allCases {
            let encoded = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(CalendarSource.self, from: encoded)
            XCTAssertEqual(decoded, source, "\(source) 인코딩/디코딩 결과가 일치하지 않습니다")
        }
    }

    func test_hashable_allCasesAreUnique() {
        XCTAssertEqual(Set(CalendarSource.allCases).count, CalendarSource.allCases.count)
    }

    func test_initFromRawValue_validString_returnsCase() {
        XCTAssertEqual(CalendarSource(rawValue: "apple"), .apple)
        XCTAssertEqual(CalendarSource(rawValue: "dozy"),  .dozy)
    }

    func test_initFromRawValue_invalidString_returnsNil() {
        XCTAssertNil(CalendarSource(rawValue: "unknown"))
        XCTAssertNil(CalendarSource(rawValue: ""))
    }
}
