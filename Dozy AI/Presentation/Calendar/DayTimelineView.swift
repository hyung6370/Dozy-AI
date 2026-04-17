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
    let onTapEvent: (String) -> Void

    private let hours = Array(0..<24)
    private let hourHeight: CGFloat = 60

    // MARK: - Partitioned events

    private var allDayEvents: [CalendarEvent] {
        events.filter { $0.isAllDay }
    }

    private var timedEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !allDayEvents.isEmpty {
                allDayStrip
                Divider()
            }

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

                        // 이벤트 카드 (너비 측정 후 겹침 레이아웃 적용)
                        Color.clear.overlay(
                            GeometryReader { geo in
                                let totalW = geo.size.width
                                ForEach(eventLayouts, id: \.event.id) { item in
                                    eventCard(
                                        item.event,
                                        col: item.col,
                                        totalCols: item.totalCols,
                                        totalWidth: totalW
                                    )
                                }
                            }
                        )
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    let hour = Calendar.current.component(.hour, from: Date())
                    proxy.scrollTo(max(0, hour - 1), anchor: .top)
                }
            }
        }
    }

    // MARK: - All-day Strip

    private var allDayStrip: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("종일")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(allDayEvents) { event in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: event.calendarColorHex) ?? .blue)
                            .frame(width: 3)
                        Text(event.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill((Color(hex: event.calendarColorHex) ?? .blue).opacity(0.15))
                    )
                    .onTapGesture { onTapEvent(event.id) }
                }
            }
            Spacer().frame(width: 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Timed Event Card

    private func eventCard(
        _ event: CalendarEvent,
        col: Int,
        totalCols: Int,
        totalWidth: CGFloat
    ) -> some View {
        let (top, height) = eventFrame(event)
        let leftPad: CGFloat = 48
        let rightPad: CGFloat = 8
        let available = totalWidth - leftPad - rightPad
        let colW = available / CGFloat(totalCols)
        let xOffset = leftPad + colW * CGFloat(col)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: event.calendarColorHex) ?? .blue)
                    .frame(width: 3)
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(height > 40 ? 2 : 1)
                Spacer(minLength: 0)
                if event.isShared {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 8))
                        .foregroundStyle((Color(hex: event.calendarColorHex) ?? .blue).opacity(0.8))
                }
            }
            if height > 36 {
                Text(event.timeRangeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 7)
            }
        }
        .padding(4)
        .frame(width: max(colW - 2, 0), height: max(height, 24), alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((Color(hex: event.calendarColorHex) ?? .blue).opacity(0.15))
        )
        .onTapGesture { onTapEvent(event.id) }
        .offset(x: xOffset, y: top)
    }

    // MARK: - Overlap Layout

    private var eventLayouts: [(event: CalendarEvent, col: Int, totalCols: Int)] {
        let sorted = timedEvents.sorted { $0.startDate < $1.startDate }
        var colEndTimes: [Date] = []
        var assignments: [(event: CalendarEvent, col: Int)] = []

        for event in sorted {
            let col = colEndTimes.firstIndex(where: { $0 <= event.startDate }) ?? colEndTimes.count
            if col == colEndTimes.count {
                colEndTimes.append(event.endDate)
            } else {
                colEndTimes[col] = max(colEndTimes[col], event.endDate)
            }
            assignments.append((event, col))
        }

        // totalCols = 해당 이벤트와 겹치는 이벤트들 중 최대 col + 1
        return assignments.map { (event, col) in
            let overlapping = assignments.filter {
                $0.event.startDate < event.endDate && $0.event.endDate > event.startDate
            }
            let maxCol = overlapping.map { $0.col }.max() ?? col
            return (event, col, maxCol + 1)
        }
    }

    // MARK: - Frame Calculation

    private func eventFrame(_ event: CalendarEvent) -> (top: CGFloat, height: CGFloat) {
        let cal = Calendar.current
        let startMin = cal.component(.hour, from: event.startDate) * 60
                     + cal.component(.minute, from: event.startDate)
        let endMin   = cal.component(.hour, from: event.endDate) * 60
                     + cal.component(.minute, from: event.endDate)
        let duration = max(endMin - startMin, 30)
        let top    = CGFloat(startMin) / 60 * hourHeight + 8
        let height = CGFloat(duration) / 60 * hourHeight
        return (top, height)
    }
}
