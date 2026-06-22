//
//  CalendarVisibilityFilter.swift
//  Dozy AI
//
//  뷰 레이어 필터 — 어떤 소스 / 어떤 공유 캘린더를 화면에 보일지 사용자가 토글.
//  CalendarSourceManager (어떤 소스를 fetch 할지) 와는 별개 레이어: fetch 는
//  그대로 두고 표시할 때만 가린다. ActiveSharedCalendarStore 의 activeCalendarID
//  와도 별개 — 그쪽은 "새 일정 저장 시 picker 기본값" 의미로만 남는다.
//

import Foundation
import Combine

final class CalendarVisibilityFilter: ObservableObject {

    @Published private(set) var hiddenSources: Set<CalendarSource>
    @Published private(set) var hiddenSharedCalendarIDs: Set<String>

    private let defaults = UserDefaults.standard
    private let sourcesKey = "dozy_hidden_calendar_sources"
    private let sharedKey = "dozy_hidden_shared_calendar_ids"

    init() {
        if let raw = defaults.array(forKey: sourcesKey) as? [String] {
            hiddenSources = Set(raw.compactMap { CalendarSource(rawValue: $0) })
        } else {
            hiddenSources = []
        }
        if let raw = defaults.array(forKey: sharedKey) as? [String] {
            hiddenSharedCalendarIDs = Set(raw)
        } else {
            hiddenSharedCalendarIDs = []
        }
        // Dozy 일정은 더 이상 필터로 끌 수 없으므로 항상 표시한다.
        // 과거 버전에서 Dozy 를 숨긴 상태로 저장한 사용자도 정상 노출되도록 마이그레이션.
        if hiddenSources.contains(.dozy) {
            hiddenSources.remove(.dozy)
            persistSources()
        }
    }

    var isFilterActive: Bool {
        !hiddenSources.isEmpty || !hiddenSharedCalendarIDs.isEmpty
    }

    // MARK: - Source

    func isVisible(_ source: CalendarSource) -> Bool {
        !hiddenSources.contains(source)
    }

    func setVisible(_ source: CalendarSource, _ visible: Bool) {
        if visible {
            hiddenSources.remove(source)
        } else {
            hiddenSources.insert(source)
        }
        persistSources()
    }

    func toggle(_ source: CalendarSource) {
        setVisible(source, !isVisible(source))
    }

    // MARK: - Shared calendar

    func isVisibleSharedCalendar(_ id: String) -> Bool {
        !hiddenSharedCalendarIDs.contains(id)
    }

    func setVisibleSharedCalendar(_ id: String, _ visible: Bool) {
        if visible {
            hiddenSharedCalendarIDs.remove(id)
        } else {
            hiddenSharedCalendarIDs.insert(id)
        }
        persistShared()
    }

    func toggleSharedCalendar(_ id: String) {
        setVisibleSharedCalendar(id, !isVisibleSharedCalendar(id))
    }

    /// 공유 캘린더 목록이 갱신되면 더 이상 존재하지 않는 ID 를 hide 셋에서 정리.
    /// 탈퇴/삭제된 캘린더 ID 가 영구히 남아있는 걸 방지.
    func reconcileSharedCalendars(with calendars: [SharedCalendar]) {
        let valid = Set(calendars.map(\.id))
        let pruned = hiddenSharedCalendarIDs.intersection(valid)
        guard pruned != hiddenSharedCalendarIDs else { return }
        hiddenSharedCalendarIDs = pruned
        persistShared()
    }

    // MARK: - Reset

    func reset() {
        hiddenSources = []
        hiddenSharedCalendarIDs = []
        persistSources()
        persistShared()
    }

    private func persistSources() {
        defaults.set(hiddenSources.map(\.rawValue), forKey: sourcesKey)
    }

    private func persistShared() {
        defaults.set(Array(hiddenSharedCalendarIDs), forKey: sharedKey)
    }
}
