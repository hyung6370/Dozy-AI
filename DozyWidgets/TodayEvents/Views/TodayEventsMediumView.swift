//
//  TodayEventsMediumView.swift
//  DozyWidgetsExtension
//
//  Created by Hyungjun KIM on 5/14/26.
//

import AppIntents
import SwiftUI
import WidgetKit

struct TodayEventsMediumView: View {
    let entry: TodayEventsEntry

    /// 표시할 일정 — 끝나지 않은 것 + 종일 일정 중 시간순 최대 3개.
    private var upcomingEvents: [WidgetEventSnapshot] {
        let now = entry.date
        return Array(
            entry.events
                .filter { $0.isAllDay || $0.end > now }
                .prefix(3)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("Dozy-AI-40x40")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("오늘 일정")
                    .font(.headline)
                Spacer()
                Text(verbatim: "\(entry.completedCount) / \(entry.totalCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if upcomingEvents.isEmpty {
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("오늘 일정 모두 완료!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer(minLength: 0)
            } else {
                // 일정 row 들이 남은 vertical 공간을 균등하게 나눠 가짐.
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(upcomingEvents, id: \.id) { ev in
                        eventRow(ev)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    /// 한 일정 = 좌측 컬러 바 + (제목 + 시간) + 우측 체크박스.
    /// 체크박스 Button 의 intent 가 실행되면 SwiftData 의 완료 상태가 토글되고
    /// 위젯 timeline 이 reload 되어 시각적으로 즉시 반영됨.
    private func eventRow(_ ev: WidgetEventSnapshot) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: ev.colorHex) ?? .accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(ev.title)
                    .font(.subheadline.weight(ev.isCompleted ? .regular : .medium))
                    .foregroundStyle(ev.isCompleted ? .secondary : .primary)
                    .strikethrough(ev.isCompleted, color: .secondary)
                    .lineLimit(1)
                Text(ev.timeRangeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 4)

            completionButton(ev)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 체크박스 — Button(intent:) 패턴으로 widget interactivity 활성화.
    /// 탭 시 ToggleEventCompletionIntent.perform 이 widget extension 프로세스에서 실행됨.
    private func completionButton(_ ev: WidgetEventSnapshot) -> some View {
        Button(intent: ToggleEventCompletionIntent(eventID: ev.id, eventDate: entry.date)) {
            Image(systemName: ev.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(ev.isCompleted ? Color.green : Color.secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
    }
}

#Preview(as: .systemMedium) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
}
