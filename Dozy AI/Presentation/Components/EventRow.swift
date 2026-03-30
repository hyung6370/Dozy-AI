//
//  EventRow.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//

import SwiftUI

struct EventRow: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // 캘린더 색상 인디케이터
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: event.calendarColorHex))
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(event.timeRangeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
