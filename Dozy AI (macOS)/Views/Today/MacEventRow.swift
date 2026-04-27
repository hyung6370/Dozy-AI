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
        let accent = Color(hex: event.calendarColorHex) ?? .blue
        return HStack(spacing: 14) {
            // 좌측: 완료 체크 표시 (todo 처럼 한눈에 상태 파악)
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompleted ? Color.green : Color.secondary.opacity(0.5))

            // 컬러 바
            RoundedRectangle(cornerRadius: 3)
                .fill(event.source == .dozy ? accent.opacity(0.5) : accent)
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    if event.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(accent)
                    }
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .strikethrough(isCompleted, color: .secondary)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                }

                HStack(spacing: 10) {
                    Text(event.timeRangeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if event.isShared {
                        Label("공유", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(accent)
                    }

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isCompleted ? 0.5 : 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accent.opacity(isCompleted ? 0 : 0.08), lineWidth: 1)
        )
    }
}
