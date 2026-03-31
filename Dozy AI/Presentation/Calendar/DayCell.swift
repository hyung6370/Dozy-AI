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
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(isSelected ? Color.blue : Color.clear))
                
                // 이벤트 바 (최대 3개)
                HStack(spacing: 2) {
                    ForEach(eventBars) { bar in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: bar.colorHex) ?? .blue)
                            .frame(width: 6, height: 3)
                    }
                }
                .frame(height: 4)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
