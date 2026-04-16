//
//  RecentLogRow.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//

import SwiftUI
import SwiftData

struct RecentLogRow: View {
    let log: WorkLog
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(log.date.formattedKorean)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !log.category.isEmpty {
                    let userCat = categories.first(where: { $0.name == log.category })
                    let emoji = userCat?.emoji ?? "📌"
                    Text("\(emoji) \(log.category)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            
            if !log.aiSummary.isEmpty {
                Text(log.aiSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("일정 \(log.rawEventTitles.count)건 · 완료 \(log.completedTaskTitles.count)건")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
