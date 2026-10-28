//
//  CalendarSourceManager.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation
import Combine

final class CalendarSourceManager: ObservableObject {
    
    @Published private(set) var enabledSources: Set<CalendarSource>
    
    private let defaults = UserDefaults.standard
    private let storageKey = "dozy_enabled_calendar_sources"
    /// 외부 캘린더 연동을 켤 때 `calendar_source_connected` 를 보낸다 (#90). DependencyContainer 가 넣는다.
    private let analytics: AnalyticsServiceProtocol

    init(analytics: AnalyticsServiceProtocol = NoopAnalyticsService()) {
        self.analytics = analytics
        if let raw = defaults.array(forKey: storageKey) as? [String] {
            var sources = Set(raw.compactMap { CalendarSource(rawValue: $0) })
            // .holiday 는 사용자 토글 없이 CompositeCalendarSerivce 에서 항상 ON 으로 처리.
            // enabledSources 에 들어있어도 무해하지만 의미 없으므로 정리.
            sources.remove(.holiday)
            enabledSources = sources
        } else {
            enabledSources = []
        }
    }
    
    func isEnabled(_ source: CalendarSource) -> Bool {
        enabledSources.contains(source)
    }
    
    func enable(_ source: CalendarSource) {
        let inserted = enabledSources.insert(source).inserted
        persist()
        if inserted { analytics.track(.calendarSourceConnected(provider: source)) }
        reportSourceCount()
    }
    
    func disable(_ source: CalendarSource) {
        enabledSources.remove(source)
        persist()
        reportSourceCount()
    }

    /// 사용자 속성 `calendar_source_count` — 앱 시작과 토글 때 갱신.
    func reportSourceCount() {
        let external = enabledSources.subtracting([.dozy, .holiday]).count
        analytics.setUserProperty(String(external), for: .calendarSourceCount)
    }
    
    func toggle(_ source: CalendarSource) {
        isEnabled(source) ? disable(source) : enable(source)
    }
    
    private func persist() {
        defaults.set(enabledSources.map(\.rawValue), forKey: storageKey)
    }
}
