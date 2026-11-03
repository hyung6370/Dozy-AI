//
//  CalendarServiceProtocol.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine

protocol CalendarServiceProtocol {
    // 특정 날짜의 캘린더 이벤트를 가져온다
    func fetchEvents(for date: Date) async throws(DozyError) -> [CalendarEvent]

    // 날짜 범위의 캘린더 이벤트를 가져온다 (인사이트용)
    func fetchEvents(from start: Date, to end: Date) async throws(DozyError) -> [CalendarEvent]

    // 캘린더 접근 권한을 요청한다
    func requestAccess() async throws(DozyError) -> Bool
}

extension CalendarServiceProtocol {
    // 오늘의 이벤트를 가져온다 (편의 메서드)
    func fetchTodayEvents() async throws(DozyError) -> [CalendarEvent] {
        try await fetchEvents(for: Date())
    }

    // 기본 구현: 하루씩 순회 (효율적인 구현이 없는 서비스용 폴백)
    func fetchEvents(from start: Date, to end: Date) async throws(DozyError) -> [CalendarEvent] {
        let cal = Calendar.current
        var all: [CalendarEvent] = []
        var cursor = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while cursor <= endDay {
            all += try await fetchEvents(for: cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return all.sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)

extension CalendarServiceProtocol {
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        .bridge { () async throws(DozyError) -> [CalendarEvent] in try await self.fetchEvents(for: date) }
    }

    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        .bridge { () async throws(DozyError) -> [CalendarEvent] in try await self.fetchEvents(from: start, to: end) }
    }

    func fetchTodayEvents() -> AnyPublisher<[CalendarEvent], DozyError> {
        .bridge { () async throws(DozyError) -> [CalendarEvent] in try await self.fetchTodayEvents() }
    }

    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        .bridge { () async throws(DozyError) -> Bool in try await self.requestAccess() }
    }
}
