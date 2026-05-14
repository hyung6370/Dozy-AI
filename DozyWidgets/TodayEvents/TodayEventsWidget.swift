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
                .containerBackground(for: .widget) {
                    // 메인 앱 설정에서 사용자가 고른 테마와 동일한 hue 의 그라디언트.
                    // App Group UserDefaults 의 "iosBackgroundTheme" 키를 매 entry 마다 읽음.
                    WidgetTheme.current().widgetBackground
                }
        }
        .configurationDisplayName("오늘 일정")
        .description("오늘 남은 Dozy 일정을 한 눈에 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled() // Apple 기본 마진 없애기
    }
}

/// 위젯 size에 따라 다른 view를 보여주는 dispatcher
struct TodayEventsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEventsEntry
    
    var body: some View {
        switch family {
        case .systemSmall:  TodayEventsSmallView(entry: entry)
        case .systemMedium: TodayEventsMediumView(entry: entry)
        case .systemLarge:  TodayEventsLargeView(entry: entry)
        default:            TodayEventsSmallView(entry: entry)
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
