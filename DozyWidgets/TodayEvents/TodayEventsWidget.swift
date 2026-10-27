//
//  TodayEventsWidget.swift
//  DozyWidgetsExtension
//
//  Created by Hyungjun KIM on 5/14/26.
//

import WidgetKit
import SwiftUI

struct TodayEventsWidget: Widget {
    static let kind = "com.dozy-ai.Dozy-AI.TodayEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: TodayEventsProvider()
        ) { entry in
            TodayEventsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘 일정")
        .description("오늘 남은 Dozy 일정을 한 눈에 확인하세요.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
        .contentMarginsDisabled() // Apple 기본 마진 없애기
    }
}

/// 위젯 size에 따라 다른 view를 보여주는 dispatcher.
/// 시스템 위젯 (Small/Medium/Large) 은 앱 테마 배경, 잠금화면 accessory 위젯은 시스템 tint 기본.
struct TodayEventsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEventsEntry

    var body: some View {
        switch family {
        case .systemSmall:
            TodayEventsSmallView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.current().widgetBackground
                }

        case .systemMedium:
            TodayEventsMediumView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.current().widgetBackground
                }

        case .systemLarge:
            TodayEventsLargeView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.current().widgetBackground
                }

        case .accessoryCircular:
            TodayEventsAccessoryCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)

        case .accessoryRectangular:
            TodayEventsAccessoryRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)

        case .accessoryInline:
            TodayEventsAccessoryInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)

        default:
            TodayEventsSmallView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.current().widgetBackground
                }
        }
    }
}

// MARK: - XCode Preview

#Preview(as: .systemSmall) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.placeholder
    TodayEventsEntry.sampleWithEvents
}

#Preview(as: .systemMedium) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
}

#Preview(as: .systemLarge) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
}

#Preview(as: .accessoryCircular) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
    TodayEventsEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
    TodayEventsEntry.placeholder
}

#Preview(as: .accessoryInline) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
    TodayEventsEntry.placeholder
}
