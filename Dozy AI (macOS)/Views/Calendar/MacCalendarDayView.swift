//
//  MacCalendarDayView.swift
//  Dozy AI (macOS)
//
//  Phase 2a — 일 뷰. 단일 날짜의 24시간 타임라인.
//

import SwiftUI

struct MacCalendarDayView: View {
    let date: Date
    let eventsByDate: [Date: [CalendarEvent]]
    let onSelectEvent: (CalendarEvent) -> Void
    let onCreateEvent: (Date) -> Void
    let onCreateEventAt: (Date) -> Void
    var onEditEvent: ((CalendarEvent) -> Void)? = nil
    var onDeleteEvent: ((CalendarEvent) -> Void)? = nil

    private let hourHeight: CGFloat = 56
    private let leftLabelWidth: CGFloat = 60

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            dateHeader
            Divider()
            allDaySection
            Divider()
            timelineScroll
        }
    }

    // MARK: - Date header

    private var dateHeader: some View {
        let cal = Calendar.current
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekdayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(cal.isDateInToday(date) ? Color.white : .primary)
                    .frame(width: 52, height: 52)
                    .background(cal.isDateInToday(date) ? Color.accentColor : Color.clear, in: Circle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Spacer()
        }
    }

    private var weekdayName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    // MARK: - All day events

    private var allDaySection: some View {
        let cal = Calendar.current
        let key = cal.startOfDay(for: date)
        let allDayEvents = (eventsByDate[key] ?? []).filter { e in
            e.isAllDay || cal.startOfDay(for: e.startDate) != cal.startOfDay(for: e.endDate)
        }

        return HStack(alignment: .top, spacing: 0) {
            Text("종일")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: leftLabelWidth, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                if allDayEvents.isEmpty {
                    Color.clear.frame(height: 20)
                } else {
                    ForEach(allDayEvents, id: \.id) { event in
                        allDayBar(event: event)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func allDayBar(event: CalendarEvent) -> some View {
        let color = Color(hex: event.calendarColorHex) ?? .blue
        // 공휴일은 빨강 시그널 유지 (다크모드 흰색 통일에서 제외).
        let foreground: Color = (colorScheme == .dark && event.source != .holiday)
            ? .white
            : color.adjustingBrightness(0.65)
        return HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 3)
            if event.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(foreground)
                    .padding(.leading, 6)
            }
            MacEventSourceIcon(source: event.source, size: 12, tint: foreground)
                .padding(.leading, event.isPinned ? 0 : 8)
            Text(event.title)
                .font(.body)
                .fontWeight(.regular)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .padding(.leading, (event.isPinned || event.source == .apple || event.source == .google) ? 0 : 8)
                .padding(.trailing, 8)
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedEventChipBackground(color: color, cornerRadius: 6)
        .padding(.trailing, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !event.isReadOnly else { return }
            onSelectEvent(event)
        }
        .contextMenu {
            if !event.isReadOnly {
                Button {
                    onEditEvent?(event)
                } label: {
                    Label("수정", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDeleteEvent?(event)
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineScroll: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                hourLabelColumn
                timelineGrid
            }
        }
    }

    private var hourLabelColumn: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: hourHeight, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.top, 2)
            }
        }
        .frame(width: leftLabelWidth)
    }

    private var timelineGrid: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // 24 시간 슬롯 (탭/더블탭/우클릭 영역 + 가로 구분선)
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        hourSlot(hour: hour)
                        if hour < 23 {
                            Divider().opacity(0.6)
                        }
                    }
                }

                // 이벤트 블록
                ForEach(timedBlocks(), id: \.event.id) { block in
                    blockView(block: block, width: geo.size.width)
                }
            }
        }
        .frame(height: hourHeight * 24)
    }

    private func hourSlot(hour: Int) -> some View {
        let slotDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return Color.clear
            .frame(height: hourHeight - 0.5)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onCreateEventAt(slotDate) }
            .contextMenu {
                Button {
                    onCreateEventAt(slotDate)
                } label: {
                    Label(String(format: "%02d:00 에 새 일정", hour), systemImage: "plus.circle")
                }
            }
    }

    private struct TimedBlock {
        let event: CalendarEvent
        let startMinute: Int
        let durationMinutes: Int
        var subCol: Int = 0
        var totalSubCols: Int = 1
    }

    private func timedBlocks() -> [TimedBlock] {
        let cal = Calendar.current
        let key = cal.startOfDay(for: date)
        let events = eventsByDate[key] ?? []
        var raw: [TimedBlock] = []
        for e in events {
            if e.isAllDay { continue }
            if cal.startOfDay(for: e.startDate) != cal.startOfDay(for: e.endDate) { continue }
            guard cal.isDate(e.startDate, inSameDayAs: date) else { continue }
            let startMin = cal.component(.hour, from: e.startDate) * 60 + cal.component(.minute, from: e.startDate)
            let endMin = cal.component(.hour, from: e.endDate) * 60 + cal.component(.minute, from: e.endDate)
            let duration = max(20, endMin - startMin)
            raw.append(TimedBlock(event: e, startMinute: startMin, durationMinutes: duration))
        }
        return assignSubColumns(raw)
    }

    /// 겹치는 이벤트를 side-by-side 로 배치하기 위한 sub-column 할당.
    private func assignSubColumns(_ blocks: [TimedBlock]) -> [TimedBlock] {
        guard !blocks.isEmpty else { return [] }
        let sorted = blocks.sorted { a, b in
            if a.event.isPinned != b.event.isPinned { return a.event.isPinned }
            if a.startMinute != b.startMinute { return a.startMinute < b.startMinute }
            return a.durationMinutes > b.durationMinutes
        }
        var assigned: [TimedBlock] = []
        var slotEndTimes: [Int] = []
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
        var finalized: [TimedBlock] = []
        for b in assigned {
            let bStart = b.startMinute
            let bEnd = b.startMinute + b.durationMinutes
            let overlapping = assigned.filter {
                $0.startMinute < bEnd && ($0.startMinute + $0.durationMinutes) > bStart
            }
            var withTotal = b
            withTotal.totalSubCols = (overlapping.map { $0.subCol }.max() ?? 0) + 1
            finalized.append(withTotal)
        }
        return finalized
    }

    private func blockView(block: TimedBlock, width: CGFloat) -> some View {
        let color = Color(hex: block.event.calendarColorHex) ?? .blue
        let subColumnWidth = width / CGFloat(block.totalSubCols)
        let y = CGFloat(block.startMinute) * (hourHeight / 60)
        let height = CGFloat(block.durationMinutes) * (hourHeight / 60)
        let xLeft = subColumnWidth * CGFloat(block.subCol) + 3
        let blockWidth = max(0, subColumnWidth - 6)

        return HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                let foreground: Color = (colorScheme == .dark && block.event.source != .holiday)
                    ? .white
                    : color.adjustingBrightness(0.65)
                HStack(spacing: 4) {
                    if block.event.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(foreground)
                    }
                    MacEventSourceIcon(source: block.event.source, size: 12, tint: foreground)
                    Text(block.event.title)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(foreground)
                        .lineLimit(2)
                }
                if height >= 50 && block.totalSubCols <= 2 {
                    Text(block.event.timeRangeString)
                        .font(.subheadline)
                        .foregroundStyle(foreground.opacity(0.85))
                }
                if height >= 80, block.totalSubCols == 1, let location = block.event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(foreground.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: blockWidth, height: height, alignment: .topLeading)
        .themedEventChipBackground(color: color, cornerRadius: 8)
        .offset(x: xLeft, y: y)
        .onTapGesture {
            guard !block.event.isReadOnly else { return }
            onSelectEvent(block.event)
        }
        .contextMenu {
            if !block.event.isReadOnly {
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
}
