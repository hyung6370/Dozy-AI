//
//  ToggleEventCompletionUseCase.swift
//  Dozy AI
//
//  홈·캘린더가 공유하는 일정 완료 토글. "어느 저장소에 쓰는가"의 규칙을 한 곳에 둔다.
//  - Dozy 비반복 일정: DozyEvent.isCompleted 직접 토글 (ToggleDozyEventCompletionUseCase)
//  - 그 외 (Apple/Google/Naver, 반복 Dozy): EventCompletion 테이블에 eventID + 날짜 키로 토글
//    · 반복 Dozy 는 발생일(startDate) 기준, 외부 캘린더는 호출자가 넘긴 기준 날짜(홈 = 오늘, 캘린더 = 선택한 날짜)
//  위젯의 ToggleEventCompletionIntent 는 같은 규칙을 SwiftData 직접 접근으로 구현하고 있다 (앱 밖이라 유스케이스를 못 쓴다).
//

import Foundation
import Combine

final class ToggleEventCompletionUseCase {

    /// 실제로 토글할 대상. 호출자는 결과를 보고 자기 상태(dozyEventsByID / 완료 맵)를 갱신한다.
    enum Target {
        case dozyEvent(DozyEvent)
        case completion(eventID: String, eventDate: Date)
    }

    private let toggleDozy: ToggleDozyEventCompletionUseCase
    private let toggleCalendar: ToggleCalendarEventCompletionUseCase

    init(toggleDozy: ToggleDozyEventCompletionUseCase, toggleCalendar: ToggleCalendarEventCompletionUseCase) {
        self.toggleDozy = toggleDozy
        self.toggleCalendar = toggleCalendar
    }

    /// 토글 대상을 정한다. Dozy 일정인데 원본 DozyEvent 를 못 찾으면 nil (토글 불가).
    static func target(for event: CalendarEvent, dozyEvent: DozyEvent?, on date: Date) -> Target? {
        if event.source == .dozy {
            guard let dozyEvent else { return nil }
            if dozyEvent.recurrenceRule == "none" { return .dozyEvent(dozyEvent) }
            return .completion(eventID: event.id, eventDate: event.startDate)
        }
        return .completion(eventID: event.id, eventDate: date)
    }

    /// - Returns: 토글 후의 완료 상태
    func execute(_ target: Target) -> AnyPublisher<Bool, DozyError> {
        switch target {
        case .dozyEvent(let dozyEvent):
            return toggleDozy.execute(dozyEvent)
                .map { dozyEvent.isCompleted }
                .eraseToAnyPublisher()
        case .completion(let eventID, let eventDate):
            return toggleCalendar.execute(eventID: eventID, eventDate: eventDate)
        }
    }

    /// 편의 진입점. 대상을 못 정하면 `.dataNotFound` 로 실패한다.
    func execute(_ event: CalendarEvent, dozyEvent: DozyEvent?, on date: Date) -> AnyPublisher<Bool, DozyError> {
        guard let target = Self.target(for: event, dozyEvent: dozyEvent, on: date) else {
            return Fail(error: DozyError.dataNotFound).eraseToAnyPublisher()
        }
        return execute(target)
    }
}
