//
//  EventEditViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine
import SwiftUI

final class EventEditViewModel: ObservableObject {
    
    @Published var title: String
    @Published var isAllDay: Bool
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var location: String
    @Published var notes: String
    @Published var selectedColor: Color
    
    let isEditing: Bool
    private let eventToEdit: DozyEvent?
    private let onSave: (DozyEvent) -> Void
    
    init(eventToEdit: DozyEvent?, selectedDate: Date, onSave: @escaping (DozyEvent) -> Void) {
        self.eventToEdit = eventToEdit
        self.onSave = onSave
        self.isEditing = eventToEdit != nil
        
        if let e = eventToEdit {
            title = e.title
            isAllDay = e.isAllDay
            startDate = e.startDate
            endDate = e.endDate
            location = e.location ?? ""
            notes = e.notes ?? ""
            selectedColor = Color(hex: e.colorHex) ?? .blue
        } else {
            let calendar = Calendar.current
            title = ""
            isAllDay = false
            startDate = calendar.date(bySettingHour: 9,  minute: 0, second: 0, of: selectedDate) ?? selectedDate
            endDate   = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            location = ""
            notes = ""
            selectedColor = .blue
        }
    }
    
    var isSavable: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    
    func save() {
        let colorHex = selectedColor.toHex() ?? "#007AFF"
        let finalEnd = isAllDay ? startDate : endDate
        
        if let event = eventToEdit {
            event.title    = title
            event.isAllDay = isAllDay
            event.startDate = startDate
            event.endDate   = finalEnd
            event.location  = location.isEmpty ? nil : location
            event.notes     = notes.isEmpty ? nil : notes
            event.colorHex  = colorHex
            onSave(event)
        } else {
            onSave(DozyEvent(
                title: title,
                startDate: startDate,
                endDate: finalEnd,
                isAllDay: isAllDay,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes,
                colorHex: colorHex
            ))
        }
    }
}
