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
    
    // 오늘의 이벤트를 가져온다 (편의 메서드)
    func fetchTodayEvents() -> AnyPublisher<[CalendarEvent], DozyError>
    
    // 캘린더 접근 권한을 요청한다
    func requestAccess() -> AnyPublisher<Bool, DozyError>
}

// fetchTodayEvents는 fetchEvents(for: Date())를 호출
extension CalendarServiceProtocol {
    func fetchTodayEvents() -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchEvents(for: Date())
    }
}
