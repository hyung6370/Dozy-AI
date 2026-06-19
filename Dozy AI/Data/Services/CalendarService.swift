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
        fetchEvents(for: date, excludeSubscriptions: false)
    }

    func fetchEvents(for date: Date, excludeSubscriptions: Bool) -> AnyPublisher<[CalendarEvent], DozyError> {
        requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[CalendarEvent], DozyError> in
                Future { promise in
                    let start = date.startOfDay
                    let end = date.startOfNextDay
                    let calendars = excludeSubscriptions
                        ? eventStore.calendars(for: .event).filter { $0.type != .subscription }
                        : nil

                    let predicate = eventStore.predicateForEvents(
                        withStart: start,
                        end: end,
                        calendars: calendars
                    )

                    let events = eventStore.events(matching: predicate)
                        .map { $0.toCalendarEvent() }
                        .sorted { $0.startDate < $1.startDate }

                    promise(.success(events))
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 날짜 범위 조회 (EventKit 네이티브 지원으로 효율적)

    func fetchEvents(from start: Date, to end: Date) -> AnyPublisher<[CalendarEvent], DozyError> {
        fetchEvents(from: start, to: end, excludeSubscriptions: false)
    }

    func fetchEvents(from start: Date, to end: Date, excludeSubscriptions: Bool) -> AnyPublisher<[CalendarEvent], DozyError> {
        requestAccessIfNeeded()
            .flatMap { [eventStore] _ -> AnyPublisher<[CalendarEvent], DozyError> in
                Future { promise in
                    let calendars = excludeSubscriptions
                        ? eventStore.calendars(for: .event).filter { $0.type != .subscription }
                        : nil

                    // EventKit의 predicateForEvents는 ~4년 범위를 넘기면 결과가 잘리는
                    // 문서화된 제약이 있음 → 1년 단위 chunked fetch로 오래된 이벤트까지 보장.
                    var collected: [EKEvent] = []
                    var chunkStart = start
                    let cal = Calendar.current
                    while chunkStart < end {
                        let chunkEnd = min(
                            cal.date(byAdding: .year, value: 1, to: chunkStart) ?? end,
                            end
                        )
                        let predicate = eventStore.predicateForEvents(
                            withStart: chunkStart, end: chunkEnd, calendars: calendars
                        )
                        collected.append(contentsOf: eventStore.events(matching: predicate))
                        chunkStart = chunkEnd
                    }

                    // 경계(연말-연초)에 걸친 이벤트 중복 제거 — 반복 이벤트 occurrence는 각각
                    // 고유한 startDate를 가지므로 eventIdentifier + startDate 조합 키 사용.
                    var seen = Set<String>()
                    let deduped = collected.filter {
                        let id = $0.eventIdentifier ?? ""
                        let key = "\(id)_\($0.startDate.timeIntervalSince1970)"
                        return seen.insert(key).inserted
                    }

                    let events = deduped
                        .map { $0.toCalendarEvent() }
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
            source: .apple,
            priority: 0,
            isPinned: false,
            category: "일반",
            sharedCalendarID: nil,
            ownerID: nil,
            externalSource: nil,
            externalEventID: nil,
            externalDeleted: false
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
                    // event(withIdentifier:)는 반복 이벤트의 첫 번째 occurrence를 반환하므로
                    // 날짜 기반 검색으로 정확한 occurrence를 찾아 삭제
                    let dayStart = Calendar.current.startOfDay(for: event.startDate)
                    let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
                    let predicate = eventStore.predicateForEvents(
                        withStart: dayStart,
                        end: dayEnd,
                        calendars: nil
                    )
                    let ekEvent = eventStore.events(matching: predicate)
                        .first { $0.eventIdentifier == event.id }

                    guard let ekEvent else {
                        promise(.failure(.calendarEventNotFound))
                        return
                    }
                    do {
                        // commit: true 로 이미 영속 저장소까지 반영되므로 reset() 불필요.
                        // eventStore.reset() 은 iOS 16+ 에서 내부 캐시를 통째로 버려
                        // 진행 중인 다른 fetch 가 stale/빈 결과를 받을 수 있어 제거.
                        try eventStore.remove(ekEvent, span: .thisEvent, commit: true)
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
