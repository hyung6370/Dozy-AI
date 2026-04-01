//
//  WeekGridView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/1/26.
//

import SwiftUI

struct WeekGridView: View {
    
    let weekDates: [Date]
    let selectedDate: Date
    let eventBars: (Date) -> [EventBarInfo]
    let onSelectDate: (Date) -> Void
    
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                Button { onSelectDate(date) } label: {
                    VStack(spacing: 4) {
                        Text(weekdays[index])
                            .font(.caption2)
                            .foregroundStyle(index == 0 ? .red : index == 6 ? .blue : .secondary)
                        
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.subheadline)
                            .fontWeight(isToday(date) ? .bold : .regular)
                            .foregroundStyle(isSelected(date) ? .white : isToday(date) ? .blue : .primary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isSelected(date) ? Color.blue : Color.clear))
                        
                        // 이벤트 바
                        HStack(spacing: 2) {
                            ForEach(eventBars(date)) { bar in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color(hex: bar.colorHex) ?? .blue)
                                    .frame(width: 6, height: 3)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
