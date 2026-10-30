//
//  EventEditViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class EventEditViewModel: ObservableObject {
    
    @Published var title: String
    @Published var isAllDay: Bool
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var location: String
    /// 자동완성 제안에서 사용자가 고른 좌표 포함 장소. nil 이면 텍스트만 입력된 케이스 — 지도 미표시.
    @Published var resolvedLocation: EventLocation?
    @Published var notes: String
    @Published var notificationMinutesBefore: Int
    @Published var recurrenceRule: String
    /// 반복 종료일을 지정했는지 (#147). false 면 계속 반복 — 저장 시 recurrenceEndDate 를 nil 로.
    @Published var recurrenceHasEndDate: Bool
    /// "날짜 지정"일 때의 종료일. 기본은 시작일로부터 1년 뒤.
    @Published var recurrenceEndDate: Date
    @Published var selectedColor: Color
    @Published var priority: Int
    @Published var isPinned: Bool
    @Published var category: String
    @Published var sharedCalendarID: String?
    let sharedCalendars: [SharedCalendar]

    let isEditing: Bool
    /// 새 일정을 어떻게 채웠는지 — 저장 시 onSave 로 함께 넘겨 `event_created(method:)` 에 쓴다 (#90).
    /// 자연어 · 음성으로 폼을 채우면 apply(_:method:) 가 바꾸고, 그 외는 manual.
    private(set) var inputMethod: EventInputMethod = .manual
    private let eventToEdit: DozyEvent?
    private let onSave: (DozyEvent, EventInputMethod) -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        eventToEdit: DozyEvent?,
        selectedDate: Date,
        sharedCalendars: [SharedCalendar] = [],
        useTimeHint: Bool = false,
        onSave: @escaping (DozyEvent, EventInputMethod) -> Void
    ) {
        self.eventToEdit = eventToEdit
        self.onSave = onSave
        self.isEditing = eventToEdit != nil
        self.sharedCalendars = sharedCalendars

        if let e = eventToEdit {
            title = e.title
            isAllDay = e.isAllDay
            startDate = e.startDate
            endDate = e.endDate
            location = e.location ?? ""
            if let lat = e.latitude, let lng = e.longitude {
                resolvedLocation = EventLocation(
                    name: e.location ?? "",
                    address: nil,
                    latitude: lat,
                    longitude: lng
                )
            } else {
                resolvedLocation = nil
            }
            notes = e.notes ?? ""
            notificationMinutesBefore = e.notificationMinutesBefore
            recurrenceRule = e.recurrenceRule
            recurrenceHasEndDate = e.recurrenceEndDate != nil
            recurrenceEndDate = e.recurrenceEndDate ?? RecurrenceSummary.defaultEndDate(for: e.startDate)
            selectedColor = Color(hex: e.colorHex) ?? .blue
            priority = e.priority
            isPinned = e.isPinned
            category = e.category
            sharedCalendarID = e.sharedCalendarID
        } else {
            let calendar = Calendar.current
            let resolvedStart: Date
            let resolvedEnd: Date
            if useTimeHint {
                // 시각 힌트 사용: selectedDate 의 hour/minute 그대로 사용, 종료는 +1시간
                resolvedStart = selectedDate
                resolvedEnd = calendar.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate
            } else {
                // 기본: 해당 날짜 오전 9시 ~ 10시
                resolvedStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                resolvedEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            }
            title = ""
            isAllDay = false
            startDate = resolvedStart
            endDate = resolvedEnd
            location = ""
            resolvedLocation = nil
            notes = ""
            notificationMinutesBefore = -1
            recurrenceRule = "none"
            // 새 반복은 기본 "계속" (#147). 이전엔 종료일이 일정 당일이라 반복이 한 번만 생겼다.
            recurrenceHasEndDate = false
            recurrenceEndDate = RecurrenceSummary.defaultEndDate(for: resolvedStart)
            selectedColor = .blue
            priority = 0
            isPinned = false
            category = UserCategory.defaultName
        }

        // 시작 시각이 바뀌면 종료가 그보다 앞이 되지 않도록 자동 보정.
        // allDay 이면 동일일자, 아니면 시작 + 1시간 으로.
        $startDate
            .dropFirst()
            .sink { [weak self] newStart in
                guard let self else { return }
                if self.endDate < newStart {
                    if self.isAllDay {
                        self.endDate = newStart
                    } else {
                        self.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
                    }
                }
                // 반복 종료일이 새 시작일보다 앞이면 당긴다 — 그대로 두면 반복이 하나도 안 생긴다 (#147)
                self.recurrenceEndDate = RecurrenceSummary.adjustedEndDate(self.recurrenceEndDate, start: newStart)
            }
            .store(in: &cancellables)
    }

    /// 입력 방식이 필요 없는 호출부(일정 수정 전용)용.
    convenience init(
        eventToEdit: DozyEvent?,
        selectedDate: Date,
        sharedCalendars: [SharedCalendar] = [],
        useTimeHint: Bool = false,
        onSave: @escaping (DozyEvent) -> Void
    ) {
        self.init(eventToEdit: eventToEdit, selectedDate: selectedDate, sharedCalendars: sharedCalendars,
                  useTimeHint: useTimeHint, onSave: { event, _ in onSave(event) })
    }

    var isSavable: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// 저장할 반복 종료일 — 반복 없음 · 계속 반복이면 nil (#147)
    var resolvedRecurrenceEndDate: Date? {
        guard recurrenceRule != "none", recurrenceHasEndDate else { return nil }
        return RecurrenceSummary.adjustedEndDate(recurrenceEndDate, start: startDate)
    }

    /// 편집 화면 반복 요약 — "매주 목요일 · 계속" (#147)
    var recurrenceSummary: String? {
        RecurrenceSummary.summary(rule: recurrenceRule, start: startDate, endDate: resolvedRecurrenceEndDate)
    }
    
    /// 자연어 파싱 결과로 폼을 채운다. 반복/알림/카테고리는 건드리지 않는다 - 사용자가 이어서 고른다
    func apply(_ draft: EventDraft, method: EventInputMethod = .naturalLanguage) {
        inputMethod = method
        title = draft.title
        isAllDay = draft.isAllDay
        startDate = draft.startDate
        endDate = draft.isAllDay ? draft.startDate : draft.endDate
        if let location = draft.location, !location.isEmpty {
            self.location = location
            resolvedLocation = nil // 좌표는 사용자가 자동완성에서 고를 때만
        }
    }
    
    func save() {
        let colorHex = selectedColor.toHex() ?? "#007AFF"
        let finalEnd = isAllDay ? startDate : endDate
        
        if let event = eventToEdit {
            event.title = title
            event.isAllDay = isAllDay
            event.startDate = startDate
            event.endDate = finalEnd
            event.location = location.isEmpty ? nil : location
            event.latitude = resolvedLocation?.latitude
            event.longitude = resolvedLocation?.longitude
            event.notes = notes.isEmpty ? nil : notes
            event.notificationMinutesBefore = notificationMinutesBefore
            event.recurrenceRule = recurrenceRule
            event.recurrenceEndDate = resolvedRecurrenceEndDate
            event.colorHex = colorHex
            event.priority = priority
            event.isPinned = isPinned
            event.category = category
            event.sharedCalendarID = sharedCalendarID
            onSave(event, inputMethod)
        } else {
            onSave(DozyEvent(
                title: title,
                startDate: startDate,
                endDate: finalEnd,
                isAllDay: isAllDay,
                location: location.isEmpty ? nil : location,
                latitude: resolvedLocation?.latitude,
                longitude: resolvedLocation?.longitude,
                notes: notes.isEmpty ? nil : notes,
                colorHex: colorHex,
                recurrenceRule: recurrenceRule,
                recurrenceEndDate: resolvedRecurrenceEndDate,
                notificationMinutesBefore: notificationMinutesBefore,
                priority: priority,
                isPinned: isPinned,
                category: category,
                sharedCalendarID: sharedCalendarID
            ), inputMethod)
        }
    }
}
