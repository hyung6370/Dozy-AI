//
//  CalendarVisibilityFilter.swift
//  Dozy AI
//
//  뷰 레이어 필터 — 어떤 소스를 화면에 보일지 사용자가 토글한다.
//  CalendarSourceManager (어떤 소스를 fetch 할지) 와는 별개 레이어:
//  fetch 는 그대로 두고, 표시할 때만 가린다.
//

import Foundation
import Combine

final class CalendarVisibilityFilter: ObservableObject {

    @Published private(set) var hiddenSources: Set<CalendarSource>

    private let defaults = UserDefaults.standard
    private let storageKey = "dozy_hidden_calendar_sources"

    init() {
        if let raw = defaults.array(forKey: storageKey) as? [String] {
            hiddenSources = Set(raw.compactMap { CalendarSource(rawValue: $0) })
        } else {
            hiddenSources = []
        }
    }

    var isFilterActive: Bool { !hiddenSources.isEmpty }

    func isVisible(_ source: CalendarSource) -> Bool {
        !hiddenSources.contains(source)
    }

    func setVisible(_ source: CalendarSource, _ visible: Bool) {
        if visible {
            hiddenSources.remove(source)
        } else {
            hiddenSources.insert(source)
        }
        persist()
    }

    func toggle(_ source: CalendarSource) {
        setVisible(source, !isVisible(source))
    }

    func reset() {
        hiddenSources = []
        persist()
    }

    private func persist() {
        defaults.set(hiddenSources.map(\.rawValue), forKey: storageKey)
    }
}
