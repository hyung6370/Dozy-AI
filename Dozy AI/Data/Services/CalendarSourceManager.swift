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
    
    /// `.holiday` 도입 시점에 한 번만 기본 ON으로 켜주기 위한 마이그레이션 플래그.
    /// 기존 사용자도 처음 한 번은 `.holiday`가 켜지고, 그 후 사용자가 끄면 OFF 유지됨
    private static let holidayDefaultMigrationKey = "dozy_holiday_default_enabled_v1"
    
    init() {
        if let raw = defaults.array(forKey: storageKey) as? [String] {
            var sources = Set(raw.compactMap { CalendarSource(rawValue: $0) })
            // Google Calendar API 심사 완료 전까지 강제 비활성화
            sources.remove(.google)
            enabledSources = sources
        } else {
            enabledSources = [.holiday]
        }
        
        // `.holiday` 1회 마이그레이션 - 기존 사용자에게도 첫 한 번은 켜주기
        // 사용자가 그 후 disable 하면 그 상태가 유지됨 (재진입 시 또 켜지지 않음)
        if !defaults.bool(forKey: Self.holidayDefaultMigrationKey) {
            enabledSources.insert(.holiday)
            defaults.set(true, forKey: Self.holidayDefaultMigrationKey)
            persist()
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
