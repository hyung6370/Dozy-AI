//
//  TodayEventsAccessoryInlineView.swift
//  DozyWidgetsExtension
//
//  잠금화면의 accessoryInline — 시계 위 한 줄 텍스트 슬롯.
//  공간이 매우 좁아 다음 일정 1건의 시간 + 제목만 표시.
//  일정이 없으면 완료 카운트를 노출.
//

import SwiftUI
import WidgetKit

struct TodayEventsAccessoryInlineView: View {
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

    var body: some View {
        if let ev = nextEvent {
            if ev.isAllDay {
                Label("\(String(localized: "종일")) · \(ev.title)", image: "MenuBarIcon")
            } else {
                Label("\(shortTime(ev.start)) · \(ev.title)", image: "MenuBarIcon")
            }
        } else if entry.totalCount > 0 {
            Label("\(entry.completedCount) / \(entry.totalCount) 완료", image: "MenuBarIcon")
        } else {
            Label("오늘 일정 없음", image: "MenuBarIcon")
        }
    }
}

#Preview(as: .accessoryInline) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
    TodayEventsEntry.placeholder
}
