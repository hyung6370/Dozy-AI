//
//  CalendarEventEditView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/2/26.
//

import SwiftUI
import SwiftData

// Apple/Google 이벤트 수정 전용 뷰

struct CalendarEventEditView: View {
    let event: CalendarEvent
    let sharedCalendars: [SharedCalendar]
    let onSave: (CalendarEventEditRequest) -> Void
    /// 공유 캘린더 선택 후 저장 시 호출. nil이면 공유 Section 숨김.
    let onShareToSharedCalendar: ((CalendarEvent, SharedCalendar) -> Void)?

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    @State private var shareTargetID: String?

    /// 이 외부 이벤트에 대응하는 Dozy 미러 스냅샷. Picker 초기값 복원용.
    @Query private var mirrors: [DozyEvent]

    @Environment(\.dismiss) private var dismiss

    init(
        event: CalendarEvent,
        sharedCalendars: [SharedCalendar] = [],
        onShareToSharedCalendar: ((CalendarEvent, SharedCalendar) -> Void)? = nil,
        onSave: @escaping (CalendarEventEditRequest) -> Void
    ) {
        self.event = event
        self.sharedCalendars = sharedCalendars
        self.onShareToSharedCalendar = onShareToSharedCalendar
        self.onSave = onSave
        _title = State(initialValue: event.title)
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.endDate)
        _isAllDay = State(initialValue: event.isAllDay)
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")

        let source = event.source.rawValue
        let extID = event.id
        _mirrors = Query(filter: #Predicate<DozyEvent> {
            $0.externalSource == source && $0.externalEventID == extID
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("제목", text: $title)
                }
                Section("시간") {
                    Toggle("종일", isOn: $isAllDay)
                    DatePicker("시작", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                        .environment(\.locale, .current)
                        .onChange(of: startDate) { _, newStart in
                            // 시작이 종료보다 뒤로 가면 종료 자동 보정 (allDay: 동일, 아니면 +1h)
                            if endDate < newStart {
                                endDate = isAllDay
                                    ? newStart
                                    : Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
                            }
                        }
                    DatePicker("종료",
                               selection: $endDate,
                               in: startDate...,
                               displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                        .environment(\.locale, .current)
                }
                if onShareToSharedCalendar != nil, !sharedCalendars.isEmpty {
                    Section("공유 캘린더") {
                        Picker("공유", selection: $shareTargetID) {
                            Text("없음").tag(String?.none)
                            ForEach(sharedCalendars) { cal in
                                Label(cal.name, systemImage: "person.2.fill")
                                    .tag(Optional(cal.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("위치") {
                    TextField("위치 (선택)", text: $location)
                }
                Section("메모") {
                    TextField("메모 (선택)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("일정 수정")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 이미 이 이벤트를 공유한 이력이 있으면 Picker에 복원.
                if shareTargetID == nil,
                   let existing = mirrors.first(where: { !$0.externalDeleted }) {
                    shareTargetID = existing.sharedCalendarID
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let edit = CalendarEventEditRequest(
                            title: title,
                            startDate: startDate,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            location: location.isEmpty ? nil : location,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(edit)
                        if let targetID = shareTargetID,
                           let target = sharedCalendars.first(where: { $0.id == targetID }) {
                            // 사용자가 편집한 내용으로 스냅샷을 만들기 위해, 편집된 값을
                            // 반영한 임시 CalendarEvent를 넘긴다.
                            let edited = CalendarEvent(
                                id: event.id, calendarId: event.calendarId,
                                title: edit.title,
                                startDate: edit.startDate, endDate: edit.endDate,
                                location: edit.location, notes: edit.notes,
                                isAllDay: edit.isAllDay,
                                calendarName: event.calendarName,
                                calendarColorHex: event.calendarColorHex,
                                source: event.source,
                                priority: event.priority, isPinned: event.isPinned,
                                category: event.category,
                                sharedCalendarID: event.sharedCalendarID,
                                ownerID: event.ownerID,
                                externalSource: event.externalSource,
                                externalEventID: event.externalEventID,
                                externalDeleted: event.externalDeleted
                            )
                            onShareToSharedCalendar?(edited, target)
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
