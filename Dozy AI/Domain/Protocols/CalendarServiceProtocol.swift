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
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError>

    // 날짜 범위의 캘린더 이벤트를 가져온다 (인사이트용)
    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError>

    // 오늘의 이벤트를 가져온다 (편의 메서드)
    func fetchTodayEvents() -> AnyPublisher<[CalendarEvent], DozyError>

    // 캘린더 접근 권한을 요청한다
    func requestAccess() -> AnyPublisher<Bool, DozyError>
}

extension CalendarServiceProtocol {
    func fetchTodayEvents() -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchEvents(for: Date())
    }

    // 기본 구현: 하루씩 순회 (효율적인 구현이 없는 서비스용 폴백)
    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        let cal = Calendar.current
        var dates: [Date] = []
        var cursor = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while cursor <= endDay {
            dates.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return Publishers.MergeMany(dates.map { fetchEvents(for: $0) })
            .collect()
            .map { $0.flatMap { $0 }.sorted { $0.startDate < $1.startDate } }
            .eraseToAnyPublisher()
    }
}
