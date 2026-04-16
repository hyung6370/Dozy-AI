//
//  FetchCalendarEventUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

// [UseCase] 날짜별 전체 캘린더 이벤트 조회 (CalendarView 전용)

final class FetchCalendarEventUseCase {
    
    private let calendarService: CalendarServiceProtocol
    
    init(calendarService: CalendarServiceProtocol) {
        self.calendarService = calendarService
    }
    
    func execute(for date: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        calendarService.fetchEvents(for: date)
    }
}
