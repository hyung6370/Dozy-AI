//
//  CalendarEventEditView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/2/26.
//

import SwiftUI

// Apple/Google 이벤트 수정 전용 뷰

struct CalendarEventEditView: View {
    let event: CalendarEvent
    let onSave: (CalendarEventEditRequest) -> Void
    
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    
    @Environment(\.dismiss) private var dismiss
    
    init(event: CalendarEvent, onSave: @escaping (CalendarEventEditRequest) -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event.title)
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.endDate)
        _isAllDay = State(initialValue: event.isAllDay)
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
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
                    DatePicker("종료", selection: $endDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
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
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
