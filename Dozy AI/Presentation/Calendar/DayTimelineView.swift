//
//  DayTimelineView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import SwiftUI

struct DayTimelineView: View {
    
    let events: [CalendarEvent]
    let date: Date
    
    private let hours = Array(0..<24)
    private let hourHeight: CGFloat = 60
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // 시간 눈금
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 8) {
                                Text(String(format: "%02d:00", hour))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 0.5)
                                    .padding(.top, 8)
                            }
                            .frame(height: hourHeight)
                            .id(hour)
                        }
                    }
                    
                    // 이벤트 카드
                    ForEach(timedEvents) { event in
                        eventCard(event)
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                // 현재 시각 근처로 스크롤
                let hour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(0, hour - 1), anchor: .top)
            }
        }
    }
    
    // MARK: - Event Card
    
    private func eventCard(_ event: CalendarEvent) -> some View {
        let (top, height) = eventFrame(event)
        return HStack(spacing: 0) {
            Spacer().frame(width: 48)  // 시간 눈금 너비
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: event.calendarColorHex) ?? .blue)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if height > 30 {
                        Text(event.timeRangeString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((Color(hex: event.calendarColorHex) ?? .blue).opacity(0.15))
            )
            .frame(height: max(height, 24))
            Spacer().frame(width: 8)
        }
        .offset(y: top)
    }
    
    // MARK: - Helpers
    
    private var timedEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }
    
    private func eventFrame(_ event: CalendarEvent) -> (CGFloat, CGFloat) {
        let cal = Calendar.current
        let startMinutes = cal.component(.hour, from: event.startDate) * 60 + cal.component(.minute, from: event.startDate)
        let endMinutes = cal.component(.hour, from: event.endDate) * 60 + cal.component(.minute, from: event.endDate)
        let duration = max(endMinutes - startMinutes, 30)
        let top = CGFloat(startMinutes) / 60 * hourHeight + 8
        let height = CGFloat(duration) / 60 * hourHeight
        return (top, height)
    }
}
