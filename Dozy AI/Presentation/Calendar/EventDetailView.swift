//
//  EventDetailView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import SwiftUI

struct EventDetailView: View {
    
    let event: CalendarEvent
    let dozyEvent: DozyEvent?
    let onEdit: ((DozyEvent) -> Void)?
    let onDelete: ((DozyEvent) -> Void)?
    let onEditCalendar: ((CalendarEvent) -> Void)?
    let onDeleteCalendar: ((CalendarEvent) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    Divider().padding(.horizontal)
                    infoSection
                    if let dozyEvent {
                        dozyActionSection(dozyEvent)
                    } else if event.source == .apple || event.source == .google {
                        calendarActionSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: event.calendarColorHex) ?? .blue)
                .frame(width: 6, height: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.title2).fontWeight(.bold)
                Text(event.calendarName)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Info
    private var infoSection: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "clock", label: "시간", value: timeString)
            
            if let location = event.location, !location.isEmpty {
                Divider().padding(.leading, 52)
                DetailRow(icon: "mappin", label: "위치", value: location)
            }
            
            if let notes = event.notes, !notes.isEmpty {
                Divider().padding(.leading, 52)
                DetailRow(icon: "note.text", label: "메모", value: notes)
            }
            
            Divider().padding(.leading, 52)
            DetailRow(icon: sourceIcon, label: "캘린더", value: event.calendarName)
            
            if let dozyEvent, dozyEvent.recurrenceRule != "none" {
                Divider().padding(.leading, 52)
                DetailRow(icon: "repeat", label: "반복", value: recurrenceLabel(dozyEvent.recurrenceRule))
            }
            
            if let dozyEvent, dozyEvent.notificationMinutesBefore >= 0 {
                Divider().padding(.leading, 52)
                DetailRow(icon: "bell", label: "알림", value: notificationLabel(dozyEvent.notificationMinutesBefore))
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Action (Dozy)

    private func dozyActionSection(_ dozyEvent: DozyEvent) -> some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 16)
            Button {
                dismiss()
                onEdit?(dozyEvent)
            } label: {
                Label("수정", systemImage: "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button(role: .destructive) {
                dismiss()
                onDelete?(dozyEvent)
            } label: {
                Label("삭제", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Action (Apple / Google)

    private var calendarActionSection: some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 16)
            Button {
                dismiss()
                onEditCalendar?(event)
            } label: {
                Label("수정", systemImage: "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button(role: .destructive) {
                dismiss()
                onDeleteCalendar?(event)
            } label: {
                Label("삭제", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helpers
    
    private var timeString: String {
        if event.isAllDay { return "종일" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M월 d일 (E) HH:mm"
        fmt.locale = Locale(identifier: "ko_KR")
        let start = fmt.string(from: event.startDate)
        fmt.dateFormat = "HH:mm"
        let end = fmt.string(from: event.endDate)
        return "\(start) ~ \(end)"
    }
    
    private var sourceIcon: String {
        switch event.source {
        case .apple: return "apple.logo"
        case .google: return "g.circle"
        case .naver: return "n.circle"
        case .dozy: return "d.circle.fill"
        }
    }
    
    private func recurrenceLabel(_ rule: String) -> String {
        switch rule {
        case "daily": return "매일"
        case "weekly": return "매주"
        case "monthly": return "매월"
        case "yearly": return "매년"
        default: return ""
        }
    }
    
    private func notificationLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "정시"
        case 60: return "1시간 전"
        default: return "\(minutes)분 전"
        }
    }
}

// MARK: - DetailRow

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .padding(.leading, 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption).foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.trailing, 16)
    }
}
