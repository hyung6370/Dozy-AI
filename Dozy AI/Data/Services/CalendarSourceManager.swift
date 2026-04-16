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
