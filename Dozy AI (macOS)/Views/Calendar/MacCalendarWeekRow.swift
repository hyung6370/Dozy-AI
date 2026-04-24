//
//  MacCalendarWeekRow.swift
//  Dozy AI (macOS)
//
//  Phase 1 — 한 주(7일) 단위 렌더링:
//   1) 베이스: 7개 MacCalendarDayCell (날짜 숫자 + 오버플로우 배지)
//   2) 오버레이: 멀티데이 이벤트 바 (GeometryReader 로 정확한 col 기반 절대 위치)
//

import SwiftUI

struct MacCalendarWeekRow: View {
    let weekDates: [Date]              // 7일
    let currentMonth: Date             // 현재 보고 있는 월 (타월 dim 판정용)
    let selectedDate: Date
    let eventsByDate: [Date: [CalendarEvent]]
    let onSelectDate: (Date) -> Void
    let onSelectEvent: (CalendarEvent) -> Void
    let onCreateEvent: (Date) -> Void  // 더블 클릭으로 새 이벤트

    // 레이아웃 상수
    private let barHeight: CGFloat = 18
    private let barSpacing: CGFloat = 2
    private let barTopOffset: CGFloat = 42   // 날짜 숫자 영역 아래부터 바 시작
    private let barHorizontalInset: CGFloat = 3

    var body: some View {
        let layout = MacCalendarBarLayoutEngine.compute(
            weekDates: weekDates,
            eventsByDate: eventsByDate
        )

        return GeometryReader { geo in
            let cellWidth = geo.size.width / 7

            ZStack(alignment: .topLeading) {
                // 베이스 셀
                HStack(spacing: 0) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { col, date in
                        MacCalendarDayCell(
                            date: date,
                            isInCurrentMonth: isInMonth(date),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            overflowCount: layout.overflowByCol[col] ?? 0
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture(count: 2) { onCreateEvent(date) }
                        .simultaneousGesture(
                            TapGesture(count: 1)
                                .onEnded { onSelectDate(date) }
                        )

                        if col < 6 {
                            Divider()
                        }
                    }
                }

                // 이벤트 바 오버레이
                ForEach(layout.bars) { bar in
                    eventBar(bar: bar, cellWidth: cellWidth)
                }
            }
        }
    }

    private func eventBar(bar: MacCalendarEventBar, cellWidth: CGFloat) -> some View {
        let span = CGFloat(bar.endCol - bar.startCol + 1)
        let width = cellWidth * span - barHorizontalInset * 2
        let xCenter = cellWidth * CGFloat(bar.startCol) + cellWidth * span / 2
        let y = barTopOffset + CGFloat(bar.stackRow) * (barHeight + barSpacing) + barHeight / 2

        return EventBarView(event: bar.event)
            .frame(width: max(0, width), height: barHeight)
            .position(x: xCenter, y: y)
            .onTapGesture { onSelectEvent(bar.event) }
    }

    private func isInMonth(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: currentMonth)
            && cal.component(.year, from: date) == cal.component(.year, from: currentMonth)
    }
}

// MARK: - EventBarView

private struct EventBarView: View {
    let event: CalendarEvent

    var body: some View {
        let color = Color(hex: event.calendarColorHex) ?? .blue
        HStack(spacing: 0) {
            Text(event.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(color.opacity(0.78), in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
    }
}
