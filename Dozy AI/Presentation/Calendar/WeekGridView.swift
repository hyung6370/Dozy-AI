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
                            .foregroundStyle((isSelected(date) || isToday(date)) ? .white : .primary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isSelected(date) ? Color.blue : isToday(date) ? Color.orange : Color.clear))
                        
                        // 이벤트 바
                        VStack(spacing: 2) {
                            let bars = eventBars(date)
                            ForEach(bars.prefix(3)) { bar in
                                EventBarView(bar: bar)
                            }
                            ForEach(0..<max(0, 3 - min(bars.count, 3)), id: \.self) { _ in
                                Color.clear.frame(height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
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
