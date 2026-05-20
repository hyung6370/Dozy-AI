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
    @Environment(\.colorScheme) private var colorScheme

    /// 파트너가 생성한 이벤트라면 파트너 표시 이름(닉네임 or "파트너"), 아니면 nil
    private var partnerTag: String? {
        guard let calID = event.sharedCalendarID else { return nil }
        guard let ownerID = event.ownerID,
              ownerID != (authViewModel.currentUser?.id ?? "") else { return nil }
        return ActiveSharedCalendarStore.shared.partnerDisplayName(for: calID)
    }

    /// 좌측 인디케이터 / 보조 텍스트(공유·파트너 라벨) 의 표시 색상.
    /// 카테고리가 어두운 색이면 다크모드에서 묻히므로 hue 유지하며 brightness 끌어올림.
    private var indicatorColor: Color {
        (Color(hex: event.calendarColorHex) ?? .blue).eventDisplayColor(in: colorScheme)
    }
    private var labelTextColor: Color {
        (Color(hex: event.calendarColorHex) ?? .blue).eventTextColor(in: colorScheme)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 캘린더 색상 인디케이터
            RoundedRectangle(cornerRadius: 3)
                .fill(event.source == .dozy
                      ? indicatorColor.opacity(0.35)
                      : indicatorColor)
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
                            .foregroundStyle(labelTextColor)
                    } else if event.isShared {
                        Label("공유", systemImage: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(labelTextColor)
                    }

                    if event.isExternalMirror && event.externalDeleted {
                        Label("원본 삭제됨", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
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
