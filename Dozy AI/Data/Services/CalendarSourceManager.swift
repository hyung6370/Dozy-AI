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

    init() {
        if let raw = defaults.array(forKey: storageKey) as? [String] {
            var sources = Set(raw.compactMap { CalendarSource(rawValue: $0) })
            // Google Calendar API 심사 완료 전까지 강제 비활성화
            sources.remove(.google)
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
        enabledSources.insert(source)
        persist()
    }
    
    func disable(_ source: CalendarSource) {
        enabledSources.remove(source)
        persist()
    }
    
    func toggle(_ source: CalendarSource) {
        isEnabled(source) ? disable(source) : enable(source)
    }
    
    private func persist() {
        defaults.set(enabledSources.map(\.rawValue), forKey: storageKey)
    }
}
