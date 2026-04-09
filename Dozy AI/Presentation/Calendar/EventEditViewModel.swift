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
    @Published var notificationMinutesBefore: Int
    @Published var recurrenceRule: String
    @Published var recurrenceEndDate: Date
    @Published var selectedColor: Color
    @Published var priority: Int
    @Published var isPinned: Bool
    @Published var category: WorkCategory
    
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
            notificationMinutesBefore = e.notificationMinutesBefore
            recurrenceRule = e.recurrenceRule
            recurrenceEndDate = e.recurrenceEndDate ?? Calendar.current.date(byAdding: .year, value: 1, to: e.startDate)!
            selectedColor = Color(hex: e.colorHex) ?? .blue
            priority = e.priority
            isPinned = e.isPinned
            category = WorkCategory(rawValue: e.category) ?? .general
        } else {
            let calendar = Calendar.current
            title = ""
            isAllDay = false
            startDate = calendar.date(bySettingHour: 9,  minute: 0, second: 0, of: selectedDate) ?? selectedDate
            endDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            location = ""
            notes = ""
            notificationMinutesBefore = -1
            recurrenceRule = "none"
            recurrenceEndDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
            selectedColor = .blue
            priority = 0
            isPinned = false
            category = .general
        }
    }
    
    var isSavable: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    
    func save() {
        let colorHex = selectedColor.toHex() ?? "#007AFF"
        let finalEnd = isAllDay ? startDate : endDate
        
        if let event = eventToEdit {
            event.title = title
            event.isAllDay = isAllDay
            event.startDate = startDate
            event.endDate = finalEnd
            event.location = location.isEmpty ? nil : location
            event.notes = notes.isEmpty ? nil : notes
            event.notificationMinutesBefore = notificationMinutesBefore
            event.recurrenceRule = recurrenceRule
            event.recurrenceEndDate = recurrenceRule == "none" ? nil : recurrenceEndDate
            event.colorHex = colorHex
            event.priority = priority
            event.isPinned = isPinned
            event.category = category.rawValue
            onSave(event)
        } else {
            onSave(DozyEvent(
                title: title,
                startDate: startDate,
                endDate: finalEnd,
                isAllDay: isAllDay,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes,
                colorHex: colorHex,
                recurrenceRule: recurrenceRule,
                recurrenceEndDate: recurrenceRule == "none" ? nil : recurrenceEndDate,
                notificationMinutesBefore: notificationMinutesBefore,
                priority: priority,
                isPinned: isPinned,
                category: category.rawValue
            ))
        }
    }
}
