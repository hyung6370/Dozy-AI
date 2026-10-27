//
//  TodayEventsAccessoryRectangularView.swift
//  DozyWidgetsExtension
//
//  잠금화면 / StandBy 의 accessoryRectangular — 직사각형 슬롯.
//  상단: menubar 캘린더 아이콘 + "오늘 일정" 라벨 + "X / Y" 카운트.
//  하단: 다음 일정 1건 (시간 + 제목). 일정 없으면 "남은 일정 없음".
//

import SwiftUI
import WidgetKit

struct TodayEventsAccessoryRectangularView: View {
    let entry: TodayEventsEntry

    private var nextEvent: WidgetEventSnapshot? {
        let now = entry.date
        return entry.events.first { $0.isAllDay || $0.end > now }
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// 탭 시 이동할 deep link URL.
    /// - 표시 중인 다음 일정이 있으면 해당 일정 상세 시트로.
    /// - 일정이 없으면 캘린더 탭으로 (호환적 fallback).
    private var tapURL: URL? {
        if let id = nextEvent?.id, !id.isEmpty {
            var components = URLComponents()
            components.scheme = "dozy-ai"
            components.host = "event-detail"
            components.queryItems = [URLQueryItem(name: "id", value: id)]
            return components.url
        }
        return URL(string: "dozy-ai://calendar")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image("MenuBarIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .widgetAccentable()
                Text("오늘 일정")
                    .font(.caption2.weight(.semibold))
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text(verbatim: "\(entry.completedCount) / \(entry.totalCount)")
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .opacity(0.8)
            }

            if let ev = nextEvent {
                Text(ev.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: ev.isAllDay ? String(localized: "종일") : shortTime(ev.start))
                    .font(.caption2)
                    .opacity(0.8)
            } else {
                Spacer(minLength: 0)
                Text("남은 일정 없음")
                    .font(.caption)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(tapURL)
    }
}

#Preview(as: .accessoryRectangular) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
    TodayEventsEntry.placeholder
}
