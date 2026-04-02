//
//  CalendarService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - Data Layer]
//  CalendarServiceProtocol의 EventKit 구현체입니다.
//  EKEvent → CalendarEvent 변환(Mapping)을 이 파일 내 private extension으로 처리합니다.
//  Domain 모델(CalendarEvent)은 EventKit을 전혀 모릅니다.

import Foundation
import Combine
import EventKit

final class CalendarService: CalendarServiceProtocol {

    // EKEventStore는 반드시 강한 참조로 유지해야 합니다
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
        requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[CalendarEvent], DozyError> in
                Future { promise in
                    let start = date.startOfDay
                    let end = date.startOfNextDay

                    let predicate = eventStore.predicateForEvents(
                        withStart: start,
                        end: end,
                        calendars: nil
                    )

                    let events = eventStore.events(matching: predicate)
                        .map { $0.toCalendarEvent() }          // ← Mapper 사용
                        .sorted { $0.startDate < $1.startDate }

                    promise(.success(events))
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    private func requestAccessIfNeeded() -> AnyPublisher<Void, DozyError> {
        Future { [eventStore] promise in
            let status = EKEventStore.authorizationStatus(for: .event)

            switch status {
            case .fullAccess, .authorized:
                promise(.success(()))

            case .notDetermined:
                eventStore.requestFullAccessToEvents { granted, _ in
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

// MARK: - EKEvent → CalendarEvent Mapper
// Domain 모델이 EventKit을 몰라도 되도록,
// 변환 로직을 Data 계층(이 파일) 안에 캡슐화합니다.

private extension EKEvent {
    func toCalendarEvent() -> CalendarEvent {
        let colorHex: String
        if let cgColor = calendar?.cgColor,
           let components = cgColor.components,
           components.count >= 3 {
            let r = Int(components[0] * 255)
            let g = Int(components[1] * 255)
            let b = Int(components[2] * 255)
            colorHex = String(format: "#%02X%02X%02X", r, g, b)
        } else {
            colorHex = "#007AFF"
        }

        return CalendarEvent(
            id: eventIdentifier ?? UUID().uuidString,
            calendarId: calendar?.calendarIdentifier,
            title: title ?? "제목 없음",
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            isAllDay: isAllDay,
            calendarName: calendar?.title ?? "",
            calendarColorHex: colorHex,
            source: .apple
        )
    }
}

extension CalendarService: CalendarWriteServiceProtocol {
    
    func updateEvent(_ event: CalendarEvent, with edit: CalendarEventEditRequest) -> AnyPublisher<Void, DozyError> {
        requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<Void, DozyError> in
                Future { promise in
                    guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
                        promise(.failure(.dataNotFound))
                        return
                    }
                    ekEvent.title = edit.title
                    ekEvent.startDate = edit.startDate
                    ekEvent.endDate = edit.endDate
                    ekEvent.isAllDay = edit.isAllDay
                    ekEvent.location = edit.location
                    ekEvent.notes = edit.notes
                    
                    do {
                        try eventStore.save(ekEvent, span: .thisEvent)
                        promise(.success(()))
                    } catch {
                        promise(.failure(.calendarWriteFailed(underlying: error)))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func deleteEvent(_ event: CalendarEvent) -> AnyPublisher<Void, DozyError> {
        requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<Void, DozyError> in
                Future { promise in
                    guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
                        promise(.failure(.dataNotFound))
                        return
                    }
                    
                    do {
                        try eventStore.remove(ekEvent, span: .thisEvent)
                        promise(.success(()))
                    } catch {
                        promise(.failure(.calendarWriteFailed(underlying: error)))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
