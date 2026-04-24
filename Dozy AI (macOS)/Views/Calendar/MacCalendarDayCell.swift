//
//  MacCalendarDayCell.swift
//  Dozy AI (macOS)
//
//  M4.5 — 월별 캘린더 그리드의 한 셀. 날짜 숫자(좌상단) + 이벤트 색상 점.
//  부모 프레임에 맞춰 세로로 flexible 하게 늘어난다.
//

import SwiftUI

struct MacCalendarDayCell: View {
    let date: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let eventColors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.white : dayColor)
                    .frame(width: 24, height: 24)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())
                Spacer()
            }

            HStack(spacing: 3) {
                ForEach(Array(eventColors.prefix(4).enumerated()), id: \.offset) { _, hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .blue)
                        .frame(width: 5, height: 5)
                }
                if eventColors.count > 4 {
                    Text("+\(eventColors.count - 4)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            isSelected && !isToday
                ? Color.accentColor.opacity(0.12)
                : Color.clear
        )
        .contentShape(Rectangle())
    }

    private var dayColor: Color {
        if !isInCurrentMonth { return .secondary.opacity(0.4) }
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1:  return .red     // Sunday
        case 7:  return .blue    // Saturday
        default: return .primary
        }
    }
}
