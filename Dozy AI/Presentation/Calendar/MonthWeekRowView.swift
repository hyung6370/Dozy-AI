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
    let isHoliday: (Date) -> Bool
    let onSelect: (Date) -> Void
    let onLongPress: (Date) -> Void
    let onTapEvent: (String, Date) -> Void
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
                    let pillDate = weekDates[min(layout.startCol, weekDates.count - 1)]
                    // pill이 걸친 컬럼 중 현재 달 날짜가 하나라도 있으면 정상 표시, 전부 인접 달이면 흐리게
                    let pillInMonth = (layout.startCol...layout.endCol).contains { isInMonth(weekDates[min($0, weekDates.count - 1)]) }

                    EventPill(layout: layout)
                        .frame(width: max(0, pillW), height: rowH)
                        .offset(x: xOff, y: yOff)
                        .opacity(pillInMonth ? 1.0 : 0.5)
                        .onTapGesture { onTapEvent(layout.eventId, pillDate) }
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
                                        .foregroundStyle(.secondary.opacity(isInMonth(date) ? 1.0 : 0.4))
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
        Text(verbatim: "\(day)")
            .font(.subheadline)
            .fontWeight(isToday(date) ? .bold : .regular)
            .foregroundStyle(dayLabelColor(date: date, inMonth: inMonth))
            .frame(width: 34, height: 34)
            .background(Circle().fill(isSelected(date) ? Color.blue : isToday(date) ? Color.orange : .clear))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 날짜 숫자 색 — 한국 캘린더 관습: 공휴일 / 일요일 빨강, 토요일 파랑.
    private func dayLabelColor(date: Date, inMonth: Bool) -> Color {
        if isSelected(date) || isToday(date) { return .white }
        guard inMonth else { return .secondary.opacity(0.4) }
        if isHoliday(date) { return .red }
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1:  return .red
        case 7:  return .blue
        default: return .primary
        }
    }
}

// MARK: - EventPill

struct EventPill: View {
    let layout: CalendarEventLayout

    @Environment(\.colorScheme) private var colorScheme

    /// 카테고리 색 (다크모드에서 너무 어두우면 자동으로 살짝 끌어올림 — fill 용 보수적 보정).
    private var color: Color {
        (Color(hex: layout.colorHex) ?? .blue).eventDisplayColor(in: colorScheme)
    }
    /// Dozy 일정 텍스트에 쓰는 색 — fill 보다 더 적극적으로 끌어올려 다크모드 가독성 확보.
    private var dozyTextColor: Color {
        (Color(hex: layout.colorHex) ?? .blue).eventTextColor(in: colorScheme)
    }
    private var isDozy: Bool { layout.source == .dozy }
    private var isGoogle: Bool { layout.source == .google }
    private var isHoliday: Bool { layout.source == .holiday }

    /// 공휴일 텍스트 색 — 라이트는 기존대로 흰색, 다크모드는 채도 있는 코랄.
    /// pill 배경(#E54848 × 0.75 ≈ 짙은 빨강) 위에 시스템 `.red` 를 올리면 둘 다 빨강이라
    /// 가독성이 떨어지고, 너무 옅으면 흰색으로 보여서 채도 있는 코랄 톤으로 분리.
    private var holidayTextColor: Color {
        colorScheme == .dark ? Color(red: 1.0, green: 0.42, blue: 0.42) : .white
    }

    /// Google 이벤트 텍스트: 같은 색조·채도 0.85·밝기 0.65 고정 → 중간 톤으로 검정과 거리를 둠
    private var googleTextColor: Color {
        if colorScheme == .dark { return .white }
        let base = UIColor(Color(hex: layout.colorHex) ?? color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: 0.85, brightness: 0.65)
    }

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
                                .foregroundStyle(isDozy ? dozyTextColor : isGoogle ? googleTextColor : isHoliday ? holidayTextColor : .white)
                        }
                        if let pc = priorityColor {
                            Circle()
                                .fill(pc)
                                .frame(width: 5, height: 5)
                        }
                        Text(layout.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isDozy ? color : isGoogle ? googleTextColor : isHoliday ? holidayTextColor : .white)
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
