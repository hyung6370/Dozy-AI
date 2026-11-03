//
//  DozyCalendarService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation

// [Data Layer] DozyEvent -> CalendarEvent 변환 서비스
// CompositeCalendarService에서 항상 포함된다

final class DozyCalendarService: CalendarServiceProtocol {
    
    private let repository: DozyEventRepositoryProtocol
    
    init(repository: DozyEventRepositoryProtocol) {
        self.repository = repository
    }
    
    func requestAccess() async throws(DozyError) -> Bool { true }
    
    func fetchEvents(for date: Date) async throws(DozyError) -> [CalendarEvent] {
        let regular = try await repository.fetchEvents(from: date.startOfDay, to: date.startOfNextDay)
        let recurring = try await repository.fetchAllRecurring()
        // 비반복 일정만 date range로 처리 (반복 일정은 occursOn으로 전개)
        let regularEvents = regular
            .filter { $0.recurrenceRule == "none" || $0.recurrenceRule.isEmpty }
            .map { $0.toCalendarEvent() }
        let recurringEvents = recurring
            .filter { $0.occursOn(date) }
            .map { $0.toCalendarEvent(for: date) }
        return (regularEvents + recurringEvents).sorted { $0.startDate < $1.startDate }
    }
    
    // MARK: - 날짜 범위 조회 (반복 일정 전개 포함)
    func fetchEvents(from start: Date, to end: Date) async throws(DozyError) -> [CalendarEvent] {
        let all = try await repository.fetchEvents(from: start, to: end)
        let recurring = try await repository.fetchAllRecurring()
        let cal = Calendar.current
        // 비반복 일정
        let nonRecurring = all
            .filter { $0.recurrenceRule == "none" || $0.recurrenceRule.isEmpty }
            .map { $0.toCalendarEvent() }
        // 반복 일정: 기간 내 각 발생일로 전개
        var expanded: [CalendarEvent] = []
        var cursor = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while cursor <= endDay {
            for event in recurring where event.occursOn(cursor) {
                expanded.append(event.toCalendarEvent(for: cursor))
            }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return (nonRecurring + expanded).sorted { $0.startDate < $1.startDate }
    }
}
