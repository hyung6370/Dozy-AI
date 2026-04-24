//
//  MacCalendarWeekView.swift
//  Dozy AI (macOS)
//
//  Phase 2a — 주 뷰. 7일 × 24시간 타임라인.
//  상단: 요일+날짜 헤더
//  중간: 종일 이벤트 바 (all-day events)
//  하단: 시간대 타임라인 그리드 + 이벤트 블록
//

import SwiftUI

struct MacCalendarWeekView: View {
    let weekDates: [Date]                       // 7일
    let selectedDate: Date
    let eventsByDate: [Date: [CalendarEvent]]
    let onSelectDate: (Date) -> Void
    let onSelectEvent: (CalendarEvent) -> Void
    let onCreateEvent: (Date) -> Void            // 종일 슬롯용 (시간 정보 없음)
    let onCreateEventAt: (Date) -> Void          // 타임라인 슬롯용 (시각 포함)
    var onEditEvent: ((CalendarEvent) -> Void)? = nil
    var onDeleteEvent: ((CalendarEvent) -> Void)? = nil

    private let hourHeight: CGFloat = 44
    private let leftLabelWidth: CGFloat = 50
    private let allDayRowMaxHeight: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            dateHeaderRow
            Divider()
            allDayRow
            Divider()
            timelineScroll
        }
    }

    // MARK: - Date Header

    private var dateHeaderRow: some View {
        let cal = Calendar.current
        return HStack(spacing: 0) {
            // 왼쪽 시간 라벨 영역 (빈칸) — 명시적 height 지정해서 세로 팽창 방지
            Color.clear
                .frame(width: leftLabelWidth, height: 54)

            Divider()

            ForEach(Array(weekDates.enumerated()), id: \.offset) { idx, date in
                VStack(spacing: 3) {
                    Text(weekdayLabel(idx))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(weekdayColor(idx))
                    Text("\(cal.component(.day, from: date))")
                        .font(.subheadline)
                        .fontWeight(cal.isDateInToday(date) ? .bold : .medium)
                        .foregroundStyle(cal.isDateInToday(date) ? Color.white : .primary)
                        .frame(width: 26, height: 26)
                        .background(cal.isDateInToday(date) ? Color.accentColor : Color.clear, in: Circle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    cal.isDate(date, inSameDayAs: selectedDate) && !cal.isDateInToday(date)
                        ? Color.accentColor.opacity(0.12)
                        : Color.clear
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelectDate(date) }

                if idx < 6 {
                    Divider()
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func weekdayLabel(_ idx: Int) -> String {
        ["일", "월", "화", "수", "목", "금", "토"][idx]
    }

    private func weekdayColor(_ idx: Int) -> Color {
        switch idx {
        case 0: return .red
        case 6: return .blue
        default: return .secondary
        }
    }

    // MARK: - All-Day Row

    private var allDayRow: some View {
        HStack(spacing: 0) {
            Text("종일")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.trailing, 6)
                .frame(width: leftLabelWidth, alignment: .trailing)

            Divider()

            GeometryReader { geo in
                let cellWidth = geo.size.width / 7
                let allDayBars = computeAllDayBars()

                ZStack(alignment: .topLeading) {
                    // 셀 분할선
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            Color.clear.frame(maxWidth: .infinity)
                            if col < 6 { Divider() }
                        }
                    }
                    // 멀티데이 바
                    ForEach(allDayBars) { bar in
                        allDayBarView(bar: bar, cellWidth: cellWidth)
                    }
                }
            }
            .frame(minHeight: 24, maxHeight: allDayRowMaxHeight)
        }
        .frame(minHeight: 24, maxHeight: allDayRowMaxHeight)
    }

    /// 종일/멀티데이 이벤트를 바로 변환 (기존 월뷰 레이아웃 엔진 재사용)
    private func computeAllDayBars() -> [MacCalendarEventBar] {
        // 종일/멀티데이 필터링: isAllDay == true 이거나 start != end 날짜
        let cal = Calendar.current
        var filtered: [Date: [CalendarEvent]] = [:]
        for (key, events) in eventsByDate {
            let pass = events.filter { e in
                e.isAllDay ||
                cal.startOfDay(for: e.startDate) != cal.startOfDay(for: e.endDate)
            }
            if !pass.isEmpty { filtered[key] = pass }
        }
        return MacCalendarBarLayoutEngine.compute(
            weekDates: weekDates,
            eventsByDate: filtered,
            maxVisibleRows: 3
        ).bars
    }

    private func allDayBarView(bar: MacCalendarEventBar, cellWidth: CGFloat) -> some View {
        let span = CGFloat(bar.endCol - bar.startCol + 1)
        let width = cellWidth * span - 6
        let xCenter = cellWidth * CGFloat(bar.startCol) + cellWidth * span / 2
        let y = 6 + CGFloat(bar.stackRow) * 20
        let color = Color(hex: bar.event.calendarColorHex) ?? .blue

        return HStack(spacing: 3) {
            if bar.event.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.leading, 6)
            }
            Text(bar.event.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .lineLimit(1)
                .padding(.leading, bar.event.isPinned ? 0 : 6)
                .padding(.trailing, 6)
            Spacer(minLength: 0)
        }
        .frame(width: max(0, width), height: 16)
        .background(color.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
        .position(x: xCenter, y: y + 8)
        .onTapGesture { onSelectEvent(bar.event) }
        .contextMenu {
            Button {
                onEditEvent?(bar.event)
            } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDeleteEvent?(bar.event)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    // MARK: - Timeline Scroll

    private var timelineScroll: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                hourLabelColumn
                Divider()
                timelineGrid
            }
        }
        .defaultScrollAnchor(.top)
    }

    private var hourLabelColumn: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: hourHeight, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 6)
                    .padding(.top, 2)
            }
        }
        .frame(width: leftLabelWidth)
    }

    private func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    private var timelineGrid: some View {
        GeometryReader { geo in
            let cellWidth = geo.size.width / 7
            ZStack(alignment: .topLeading) {
                // 베이스: 7 columns × 24 hour slots 로 세로/가로 구분선 + 탭/우클릭 영역
                HStack(spacing: 0) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { _, date in
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                hourSlot(date: date, hour: hour)
                                if hour < 23 {
                                    Divider().opacity(0.6)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if Calendar.current.compare(date, to: weekDates.last ?? date, toGranularity: .day) != .orderedSame {
                            Divider()
                        }
                    }
                }

                // 이벤트 블록
                ForEach(timedEventBlocks(), id: \.id) { block in
                    eventBlockView(block: block, cellWidth: cellWidth)
                }
            }
        }
        .frame(height: hourHeight * 24)
    }

    private func hourSlot(date: Date, hour: Int) -> some View {
        let slotDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return Color.clear
            .frame(height: hourHeight - 0.5)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onCreateEventAt(slotDate) }
            .simultaneousGesture(TapGesture(count: 1).onEnded { onSelectDate(date) })
            .contextMenu {
                Button {
                    onCreateEventAt(slotDate)
                } label: {
                    Label(String(format: "%02d:00 에 새 일정", hour), systemImage: "plus.circle")
                }
            }
    }

    // MARK: - Timed Event Blocks

    private struct TimedBlock: Identifiable {
        let id: String
        let event: CalendarEvent
        let col: Int
        let startMinute: Int
        let durationMinutes: Int
        var subCol: Int = 0        // overlap 그룹 내 sub-column 인덱스
        var totalSubCols: Int = 1  // 해당 블록이 속한 overlap 그룹의 총 sub-column 수
    }

    private func timedEventBlocks() -> [TimedBlock] {
        let cal = Calendar.current
        var raw: [TimedBlock] = []
        var seen = Set<String>()
        for (col, date) in weekDates.enumerated() {
            let key = cal.startOfDay(for: date)
            guard let events = eventsByDate[key] else { continue }
            for e in events {
                if e.isAllDay { continue }
                if cal.startOfDay(for: e.startDate) != cal.startOfDay(for: e.endDate) { continue }
                guard cal.isDate(e.startDate, inSameDayAs: date) else { continue }

                let key2 = "\(e.id)_\(col)"
                if seen.contains(key2) { continue }
                seen.insert(key2)

                let startMin = cal.component(.hour, from: e.startDate) * 60 + cal.component(.minute, from: e.startDate)
                let endMin = cal.component(.hour, from: e.endDate) * 60 + cal.component(.minute, from: e.endDate)
                let duration = max(20, endMin - startMin)
                raw.append(TimedBlock(
                    id: key2, event: e, col: col,
                    startMinute: startMin, durationMinutes: duration
                ))
            }
        }

        // 각 day column 별로 overlap sub-column 할당
        var result: [TimedBlock] = []
        for col in 0..<7 {
            let dayBlocks = raw.filter { $0.col == col }
            result.append(contentsOf: assignSubColumns(dayBlocks))
        }
        return result
    }

    /// 같은 날 안의 겹치는 이벤트에게 sub-column 을 greedy 로 할당.
    /// totalSubCols 는 각 블록과 겹치는 모든 블록의 max subCol + 1.
    private func assignSubColumns(_ blocks: [TimedBlock]) -> [TimedBlock] {
        guard !blocks.isEmpty else { return [] }
        let sorted = blocks.sorted { a, b in
            if a.event.isPinned != b.event.isPinned { return a.event.isPinned }
            if a.startMinute != b.startMinute { return a.startMinute < b.startMinute }
            return a.durationMinutes > b.durationMinutes
        }

        var assigned: [TimedBlock] = []
        var slotEndTimes: [Int] = []   // slotIdx → 해당 sub-column 의 마지막 endMin

        for var b in sorted {
            var placed = false
            for (idx, endTime) in slotEndTimes.enumerated() {
                if b.startMinute >= endTime {
                    b.subCol = idx
                    slotEndTimes[idx] = b.startMinute + b.durationMinutes
                    assigned.append(b)
                    placed = true
                    break
                }
            }
            if !placed {
                b.subCol = slotEndTimes.count
                slotEndTimes.append(b.startMinute + b.durationMinutes)
                assigned.append(b)
            }
        }

        // overlap 그룹별 totalSubCols 계산
        var finalized: [TimedBlock] = []
        for b in assigned {
            let bStart = b.startMinute
            let bEnd = b.startMinute + b.durationMinutes
            let overlappingSubCols = assigned
                .filter { $0.startMinute < bEnd && ($0.startMinute + $0.durationMinutes) > bStart }
                .map { $0.subCol }
            var withTotal = b
            withTotal.totalSubCols = (overlappingSubCols.max() ?? 0) + 1
            finalized.append(withTotal)
        }
        return finalized
    }

    private func eventBlockView(block: TimedBlock, cellWidth: CGFloat) -> some View {
        let color = Color(hex: block.event.calendarColorHex) ?? .blue
        let subColumnWidth = cellWidth / CGFloat(block.totalSubCols)
        let y = CGFloat(block.startMinute) * (hourHeight / 60)
        let height = CGFloat(block.durationMinutes) * (hourHeight / 60)
        let xLeft = cellWidth * CGFloat(block.col) + subColumnWidth * CGFloat(block.subCol) + 2
        let width = max(0, subColumnWidth - 3)

        return HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    if block.event.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Text(block.event.title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .lineLimit(2)
                }
                if height >= 36 && block.totalSubCols <= 2 {
                    Text(block.event.timeRangeString)
                        .font(.system(size: 9))
                        .foregroundStyle(color.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background(color.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
        .offset(x: xLeft, y: y)
        .onTapGesture { onSelectEvent(block.event) }
        .contextMenu {
            Button {
                onEditEvent?(block.event)
            } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDeleteEvent?(block.event)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}
