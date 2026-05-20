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
    /// 캡쳐(ImageRenderer)용 — ScrollView 가 ImageRenderer 안에서 content 를 안 펼치는 이슈가 있어,
    /// 캡쳐 시에는 ScrollView 없이 24시간 전체를 VStack 으로 평탄하게 깔아 렌더한다.
    var captureMode: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private let hours = Array(0..<24)
    private let hourHeight: CGFloat = 60
    /// 이벤트의 시각적 최소 점유 분 수.
    /// 10분 등 짧은 일정도 사용자가 제목/시간을 읽을 수 있어야 하므로 최소 높이를 30분 분량으로 잡고,
    /// **컬럼 패킹·겹침 판정에도 동일한 값을 사용**해 짧은 일정 직후에 시작하는 일정이 시각적으로
    /// 겹쳐 그려지는 걸 막는다.
    private let minVisualDurationMinutes: Int = 30

    // MARK: - Partitioned events

    private var allDayEvents: [CalendarEvent] {
        events.filter { $0.isAllDay }
    }

    private var timedEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }

    /// 카테고리 색 (다크모드에서 너무 어두우면 자동으로 살짝 끌어올림).
    private func eventColor(_ event: CalendarEvent) -> Color {
        (Color(hex: event.calendarColorHex) ?? .blue).eventDisplayColor(in: colorScheme)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !allDayEvents.isEmpty {
                allDayStrip
                Divider()
            }

            if captureMode {
                // 캡쳐 모드: ScrollView 없이 평탄하게 → ImageRenderer 가 24시간 전체를 onscreen 으로 렌더.
                timelineContent
                    .padding(.vertical, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        timelineContent
                            .padding(.vertical, 8)
                    }
                    .onAppear {
                        let hour = Calendar.current.component(.hour, from: Date())
                        proxy.scrollTo(max(0, hour - 1), anchor: .top)
                    }
                }
            }
        }
    }

    /// 시간 눈금 + 이벤트 카드 — ScrollView 안/밖 모두 동일 레이아웃 (캡쳐 호환).
    private var timelineContent: some View {
        ZStack(alignment: .topLeading) {
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
                    let c = eventColor(event)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(c)
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
                            .fill(c.opacity(0.15))
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

        let c = eventColor(event)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(c)
                    .frame(width: 3)
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(height > 40 ? 2 : 1)
                Spacer(minLength: 0)
                if event.isShared {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(c.opacity(0.8))
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
                .fill(c.opacity(0.15))
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
            let visualEnd = visualEndDate(event)
            let col = colEndTimes.firstIndex(where: { $0 <= event.startDate }) ?? colEndTimes.count
            if col == colEndTimes.count {
                colEndTimes.append(visualEnd)
            } else {
                colEndTimes[col] = max(colEndTimes[col], visualEnd)
            }
            assignments.append((event, col))
        }

        // totalCols = 해당 이벤트와 시각적으로 겹치는 이벤트들 중 최대 col + 1.
        // 실제 endDate 가 아니라 visualEndDate 로 비교해야 짧은 일정의 시각 점유 영역까지 잡힌다.
        return assignments.map { (event, col) in
            let visualEnd = visualEndDate(event)
            let overlapping = assignments.filter {
                $0.event.startDate < visualEnd && visualEndDate($0.event) > event.startDate
            }
            let maxCol = overlapping.map { $0.col }.max() ?? col
            return (event, col, maxCol + 1)
        }
    }

    /// 이벤트가 시각적으로 점유하는 "끝 시각" — 실제 endDate 와 (start + 최소 시각 길이) 중 더 늦은 쪽.
    private func visualEndDate(_ event: CalendarEvent) -> Date {
        let minEnd = event.startDate
            .addingTimeInterval(TimeInterval(minVisualDurationMinutes * 60))
        return max(event.endDate, minEnd)
    }

    // MARK: - Frame Calculation

    private func eventFrame(_ event: CalendarEvent) -> (top: CGFloat, height: CGFloat) {
        let cal = Calendar.current
        let startMin = cal.component(.hour, from: event.startDate) * 60
                     + cal.component(.minute, from: event.startDate)
        let endMin   = cal.component(.hour, from: event.endDate) * 60
                     + cal.component(.minute, from: event.endDate)
        let duration = max(endMin - startMin, minVisualDurationMinutes)
        let top    = CGFloat(startMin) / 60 * hourHeight + 8
        let height = CGFloat(duration) / 60 * hourHeight
        return (top, height)
    }
}
