//
//  MacCalendarDayCell.swift
//  Dozy AI (macOS)
//
//  Phase 1 캘린더 고도화 — 날짜 숫자 + 오늘/선택 표시 + "+N more" 오버플로우 배지.
//  이벤트 바는 WeekRow 의 ZStack 오버레이 레이어에서 렌더링되므로 셀 자체에선 안 그린다.
//

import SwiftUI

struct MacCalendarDayCell: View {
    let date: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let isHoliday: Bool       // 한국 캘린더 관습대로 공휴일이면 날짜 숫자도 빨강.
    let overflowCount: Int    // +N 표시용. 0 이면 숨김.

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.title3)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(isToday ? Color.white : dayColor)
                    .frame(width: 34, height: 34)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())
                Spacer()
            }

            Spacer(minLength: 0)

            if overflowCount > 0 {
                HStack {
                    Text("+\(overflowCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : Color.clear
        )
        .contentShape(Rectangle())
    }

    private var dayColor: Color {
        if !isInCurrentMonth { return .secondary.opacity(0.4) }
        if isHoliday { return .red }
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1:  return .red
        case 7:  return .blue
        default: return .primary
        }
    }
}
