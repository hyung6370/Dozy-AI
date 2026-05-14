//
//  TodayEventsLargeView.swift
//  DozyWidgetsExtension
//
//  systemLarge — 정사각형 큰 위젯. 미니 월간 캘린더 (메인) + 오늘 일정 리스트 (하단).
//

import SwiftUI
import WidgetKit

struct TodayEventsLargeView: View {
    let entry: TodayEventsEntry

    /// 하단에 표시할 다음 일정들 — 이미 끝난 건 제외.
    /// 종일 일정은 "오늘 하루 종일" 이라 HH:mm 비교 무의미 — 무조건 포함.
    private var upcomingEvents: [WidgetEventSnapshot] {
        let now = entry.date
        return entry.events.filter { $0.isAllDay || $0.end > now }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 컴팩트 헤더 — 월/년 + 완료 카운트 (한 줄).
            header
                .padding(.bottom, 6)

            // 미니 월간 캘린더 — vertical 공간을 모두 차지.
            MonthGrid(
                referenceDate: entry.date,
                eventDates: entry.monthEventDates
            )
            .frame(maxHeight: .infinity)

            // Divider — 캘린더와 일정 리스트 시각 분리.
            Divider()
                .padding(.vertical, 6)

            // 하단 일정 리스트 — 다음 일정 최대 3개.
            eventsFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(14)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthYearTitle)
                .font(.headline)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(verbatim: "\(entry.completedCount) / \(entry.totalCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monthYearTitle: String {
        // dateFormat 자체를 localize — ko: "2026년 5월" / en: "May 2026" (PR #7 패턴).
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = String(localized: "yyyy년 M월")
        return f.string(from: entry.date)
    }

    // MARK: - Events Footer

    @ViewBuilder
    private var eventsFooter: some View {
        if upcomingEvents.isEmpty {
            HStack {
                Spacer()
                Text(entry.totalCount == 0 ? "오늘 일정 없음" : "오늘 일정 모두 완료!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(height: 56, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(upcomingEvents.prefix(3), id: \.id) { ev in
                    eventRow(ev)
                }
                if upcomingEvents.count > 3 {
                    Text(verbatim: "+ \(upcomingEvents.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 13)
                }
            }
        }
    }

    private func eventRow(_ ev: WidgetEventSnapshot) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: ev.colorHex) ?? .accentColor)
                .frame(width: 3, height: 16)
            Text(ev.timeRangeString.split(separator: " ~ ").first.map(String.init) ?? ev.timeRangeString)
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
            Text(ev.title)
                .font(.caption.weight(ev.isCompleted ? .regular : .medium))
                .foregroundStyle(ev.isCompleted ? .secondary : .primary)
                .strikethrough(ev.isCompleted, color: .secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Mini Month Grid

/// 큰 위젯에 들어갈 미니 월간 캘린더. 일정 있는 날은 dot, 오늘은 원형 highlight.
/// 부모로부터 받은 공간을 모두 채우도록 `maxHeight: .infinity` 와 GeometryReader 사용.
struct MonthGrid: View {
    let referenceDate: Date
    let eventDates: Set<Date>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            weekdayRow
            datesGrid
        }
    }

    // MARK: Weekday header

    private var weekdayRow: some View {
        var cal = calendar
        cal.locale = .current
        let symbols = cal.veryShortWeekdaySymbols
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { idx, sym in
                Text(sym)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(weekdayColor(for: idx))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayColor(for index: Int) -> Color {
        switch index {
        case 0: return .red
        case 6: return .blue
        default: return .secondary
        }
    }

    // MARK: Dates grid — 남는 vertical 공간을 row 별로 균등 분배.

    private var datesGrid: some View {
        GeometryReader { geo in
            let rows = numberOfRows
            // row 간 spacing 합 (rows - 1) * 2 를 빼고 균등 분배.
            let rowSpacing: CGFloat = 2
            let rowHeight = max(0, (geo.size.height - CGFloat(rows - 1) * rowSpacing) / CGFloat(rows))

            VStack(spacing: rowSpacing) {
                ForEach(0..<rows, id: \.self) { rowIdx in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = rowIdx * 7 + col
                            cell(for: monthDays[safe: idx] ?? nil)
                                .frame(maxWidth: .infinity)
                                .frame(height: rowHeight)
                        }
                    }
                }
            }
        }
    }

    /// 이번 달의 모든 cell. 앞쪽 leading 빈 칸은 nil 로 채워 grid 가 요일과 맞도록.
    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: referenceDate) else { return [] }
        let firstOfMonth = interval.start
        let leadingEmpty = calendar.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for d in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: d, to: firstOfMonth) {
                cells.append(date)
            }
        }
        return cells
    }

    /// 이번 달 표시에 필요한 row 수 (4~6). 짧은 2월은 4행, 보통 5~6행.
    private var numberOfRows: Int {
        let count = monthDays.count
        return Int((Double(count) / 7.0).rounded(.up))
    }

    @ViewBuilder
    private func cell(for date: Date?) -> some View {
        if let date {
            let isToday = calendar.isDateInToday(date)
            let hasEvent = eventDates.contains(calendar.startOfDay(for: date))
            let day = calendar.component(.day, from: date)
            let weekday = calendar.component(.weekday, from: date)

            VStack(spacing: 0) {
                Text(verbatim: "\(day)")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(textColor(isToday: isToday, weekday: weekday))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isToday ? Color.accentColor : Color.clear)
                    )
                Circle()
                    .fill(hasEvent ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
                    .padding(.top, 2)
            }
        } else {
            Color.clear
        }
    }

    private func textColor(isToday: Bool, weekday: Int) -> Color {
        if isToday { return .white }
        switch weekday {
        case 1: return .red
        case 7: return .blue
        default: return .primary
        }
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
}
