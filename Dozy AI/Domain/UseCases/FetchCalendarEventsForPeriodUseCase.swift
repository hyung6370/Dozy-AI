//
//  FetchCalendarEventsForPeriodUseCase.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/9/26.
//  도지·구글·애플 모든 캘린더 소스의 이벤트를 날짜 범위로 조회합니다.
//  인사이트 대시보드에서 사용합니다.

import Foundation
import Combine

final class FetchCalendarEventsForPeriodUseCase {

    private let calendarService: CompositeCalendarSerivce

    init(calendarService: CompositeCalendarSerivce) {
        self.calendarService = calendarService
    }

    func execute(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        calendarService.fetchEvents(from: start, to: end)
    }
}
