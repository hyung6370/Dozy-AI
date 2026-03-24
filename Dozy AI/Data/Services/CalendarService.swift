//
//  CalendarService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine
import EventKit

final class CalendarService: CalendarServiceProtocol {
    
    // EKEventScore는 반드시 강한 참조로 유지해야함
    private let eventStore = EKEventStore()
    
    // MARK: - 권한 요청
    func requestAccess() -> AnyPublisher<Bool, DozyError> {
        Future { [eventStore] promise in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    promise(.failure(.calendarFetchFailed(underlying: error)))
                } else {
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 이벤트 조회
    func fetchEvents(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        
        // 먼저 권한 확인 -> 이벤트 fetch 순서로 진행
        return requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[CalendarEvent], DozyError> in
                Future { promise in
                    let start = date.startOfDay
                    let end = date.startOfNextDay
                    
                    // EventKit predicate로 해당 날짜 범위의 이벤트 검색
                    let predicate = eventStore.predicateForEvents(
                        withStart: start,
                        end: end,
                        calendars: nil // nil = 모든 캘린더
                    )
                    
                    let ekEvents = eventStore.events(matching: predicate)
                    
                    // EKEvent -> CalendarEvent 변환 + 시작 시간순 정렬
                    let events = ekEvents
                        .map { CalendarEvent(from: $0) }
                        .sorted { $0.startDate < $1.startDate }
                    
                    promise(.success(events))
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helpers
    
    // 현재 권한 상태를 확인하고, 필요하면 요청
    private func requestAccessIfNeeded() -> AnyPublisher<Void, DozyError> {
        Future { [eventStore] promise in
            let status = EKEventStore.authorizationStatus(for: .event)
            
            switch status {
            case .fullAccess, .authorized:
                promise(.success(()))
                
            case .notDetermined:
                eventStore.requestFullAccessToEvents { granted, error in
                    if granted {
                        promise(.success(()))
                    } else {
                        promise(.failure(.calendarAccessDenied))
                    }
                }
                
            case .denied, .restricted, .writeOnly:
                promise(.failure(.calendarAccessDenied))
                
            @unknown default:
                promise(.failure(.calendarAccessDenied))
            }
        }
        .eraseToAnyPublisher()
    }
}
