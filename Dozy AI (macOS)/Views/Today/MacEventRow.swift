//
//  MacEventRow.swift
//  Dozy AI (macOS)
//
//  iOS EventRow 와 같은 시각 언어를 따르되 공유 캘린더 파트너 태그 / 외부 미러 등
//  macOS 에서 아직 지원하지 않는 요소는 생략한 단순화 버전.
//

import SwiftUI

struct MacEventRow: View {
    let event: CalendarEvent
    var isCompleted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.source == .dozy
                      ? (Color(hex: event.calendarColorHex) ?? .blue).opacity(0.35)
                      : Color(hex: event.calendarColorHex) ?? .blue)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if event.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: event.calendarColorHex) ?? .blue)
                    }
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(isCompleted, color: .secondary)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                }

                HStack(spacing: 8) {
                    Text(event.timeRangeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if event.isShared {
                        Label("공유", systemImage: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: event.calendarColorHex) ?? .blue)
                    }

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}
