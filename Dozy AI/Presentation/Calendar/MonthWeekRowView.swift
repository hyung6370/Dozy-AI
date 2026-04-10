//
//  MonthWeekRowView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/2/26.
//

import SwiftUI

struct MonthWeekRowView: View {
    
    let weekDates: [Date]
    let layouts: [CalendarEventLayout]
    let selectedDate: Date
    let isToday: (Date) -> Bool
    let isSelected: (Date) -> Bool
    let isInMonth: (Date) -> Bool
    let onSelect: (Date) -> Void
    let onLongPress: (Date) -> Void
    let onTapEvent: (String) -> Void
    let onOverflowTap: (Date) -> Void
    
    private let headerH: CGFloat = 42
    private let rowH: CGFloat = 20
    private let rowGap: CGFloat = 2
    private let maxRows = 3
    
    private var totalH: CGFloat {
        headerH + CGFloat(maxRows) * (rowH + rowGap) + 18
    }
    
    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / 7
            ZStack(alignment: .topLeading) {

                // 빈 영역 탭 → 날짜 선택 / 롱프레스 → 일정 생성
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let date = weekDates[col]
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(date) }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onLongPress(date)
                                    }
                            )
                            .frame(width: cellW, height: totalH)
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(height: 0.5)
                            }
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(height: 0.5)
                            }
                    }
                }

                // 날짜 헤더
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let date = weekDates[col]
                        Button { onSelect(date) } label: {
                            dayLabel(date: date)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onLongPress(date)
                                }
                        )
                        .frame(width: cellW, height: headerH)
                    }
                }
                
                // 이벤트 pill
                ForEach(layouts.filter { $0.row < maxRows }) { layout in
                    let xOff = cellW * CGFloat(layout.startCol) + (layout.isActualStart ? 2 : 0)
                    let pillW = cellW * CGFloat(layout.endCol - layout.startCol + 1) - (layout.isActualStart ? 2 : 0) - (layout.isActualEnd ? 2 : 0)
                    let yOff = headerH + CGFloat(layout.row) * (rowH + rowGap)
                    
                    EventPill(layout: layout)
                        .frame(width: max(0, pillW), height: rowH)
                        .offset(x: xOff, y: yOff)
                        .onTapGesture { onTapEvent(layout.id) }
                }
                
                // 넘침 표시
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let over = layouts.filter {
                            $0.startCol <= col && $0.endCol >= col && $0.row >= maxRows
                        }.count
                        ZStack {
                            if over > 0 {
                                let date = weekDates[col]
                                Button {
                                    onOverflowTap(date)
                                } label: {
                                    Text("+\(over)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: cellW)
                    }
                }
                .offset(y: headerH + CGFloat(maxRows) * (rowH + rowGap) + 2)
            }
        }
        .frame(height: totalH)
    }
    
    @ViewBuilder
    private func dayLabel(date: Date) -> some View {
        let day = Calendar.current.component(.day, from: date)
        let inMonth = isInMonth(date)
        Text("\(day)")
            .font(.subheadline)
            .fontWeight(isToday(date) ? .bold : .regular)
            .foregroundStyle(
                (isSelected(date) || isToday(date)) ? .white :
                inMonth ? Color.primary : Color.secondary.opacity(0.4)
            )
            .frame(width: 34, height: 34)
            .background(Circle().fill(isSelected(date) ? Color.blue : isToday(date) ? Color.orange : .clear))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - EventPill

struct EventPill: View {
    let layout: CalendarEventLayout

    private var color: Color { Color(hex: layout.colorHex) ?? .blue }
    private var isDozy: Bool { layout.source == .dozy }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: layout.isActualStart ? 8 : 0,
            bottomLeadingRadius: layout.isActualStart ? 8 : 0,
            bottomTrailingRadius: layout.isActualEnd ? 8 : 0,
            topTrailingRadius: layout.isActualEnd ? 8 : 0
        )
    }

    private var priorityColor: Color? {
        switch layout.priority {
        case 1: return .red
        case 2: return .yellow
        case 3: return .blue
        default: return nil
        }
    }

    var body: some View {
        shape
            .fill(isDozy ? color.opacity(0.2) : color.opacity(0.75))
            .overlay(alignment: .leading) {
                if layout.isActualStart {
                    HStack(spacing: 2) {
                        if layout.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(isDozy ? color : .white)
                        }
                        if let pc = priorityColor {
                            Circle()
                                .fill(pc)
                                .frame(width: 5, height: 5)
                        }
                        Text(layout.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isDozy ? color : .white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 5)
                    .padding(.trailing, 2)
                }
            }
            .clipped()
    }
}
//
//#Preview {
//    MonthWeekRowView(
//        weekDates: (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: Date()) },
//        layouts: [],
//        selectedDate: Date(),
//        isToday: { _ in false },
//        isSelected: { _ in false },
//        onSelect: { _ in },
//        onTapEvent: { _ in }
//    )
//}
