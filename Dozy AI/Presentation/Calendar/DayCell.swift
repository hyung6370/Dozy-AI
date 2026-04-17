//
//  DayCell.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI

struct DayCell: View {

    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let eventBars: [EventBarInfo]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle((isSelected || isToday) ? .white : .primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(isSelected ? Color.blue : isToday ? Color.orange : Color.clear))

                VStack(spacing: 2) {
                    ForEach(eventBars.prefix(3)) { bar in
                        EventBarView(bar: bar)
                    }
                    // 빈 슬롯 유지 (셀 높이 고정)
                    ForEach(0..<max(0, 3 - min(eventBars.count, 3)), id: \.self) { _ in
                        Color.clear.frame(height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - EventBarView

struct EventBarView: View {

    let bar: EventBarInfo

    private var color: Color { Color(hex: bar.colorHex) ?? .blue }

    var body: some View {
        switch bar.position {
        case .single:
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                if bar.isShared {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 4))
                        .foregroundStyle(color)
                        .offset(x: 5, y: -3)
                }
            }
            .frame(maxWidth: .infinity)
        case .start:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity)
                UnevenRoundedRectangle(
                    topLeadingRadius: 3, bottomLeadingRadius: 3,
                    bottomTrailingRadius: 0, topTrailingRadius: 0
                )
                .fill(color)
                .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
            }
        case .middle:
            Rectangle()
                .fill(color)
                .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
        case .end:
            HStack(spacing: 0) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 3, topTrailingRadius: 3
                )
                .fill(color)
                .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
