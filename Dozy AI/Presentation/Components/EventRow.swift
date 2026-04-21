//
//  EventRow.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//

import SwiftUI

struct EventRow: View {
    let event: CalendarEvent
    var isCompleted: Bool = false
    var onToggle: (() -> Void)? = nil
    @EnvironmentObject private var authViewModel: AuthViewModel

    /// 파트너가 생성한 이벤트라면 파트너 표시 이름(닉네임 or "파트너"), 아니면 nil
    private var partnerTag: String? {
        guard let calID = event.sharedCalendarID else { return nil }
        guard let ownerID = event.ownerID,
              ownerID != (authViewModel.currentUser?.id ?? "") else { return nil }
        return ActiveSharedCalendarStore.shared.partnerDisplayName(for: calID)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 캘린더 색상 인디케이터
            RoundedRectangle(cornerRadius: 3)
                .fill(event.source == .dozy
                      ? (Color(hex: event.calendarColorHex) ?? .blue).opacity(0.35)
                      : Color(hex: event.calendarColorHex) ?? .blue)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(event.timeRangeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let partnerTag {
                        Label(partnerTag, systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: event.calendarColorHex) ?? .blue)
                    } else if event.isShared {
                        Label("공유", systemImage: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: event.calendarColorHex) ?? .blue)
                    }

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let onToggle {
                Button(action: onToggle) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isCompleted ? .green : Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
