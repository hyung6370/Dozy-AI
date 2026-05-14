//
//  TodayEventsAccessoryCircularView.swift
//  DozyWidgetsExtension
//
//  잠금화면 / StandBy 의 accessoryCircular — 시계 옆 원형 슬롯.
//  "일정 추가" 버튼 역할. 탭하면 `dozy-ai://add-event` 로 deep link →
//  메인 앱이 홈 탭에서 일정 생성 바텀시트를 띄움.
//

import SwiftUI
import WidgetKit

struct TodayEventsAccessoryCircularView: View {
    let entry: TodayEventsEntry

    private static let addEventURL = URL(string: "dozy-ai://add-event")

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                Text("일정")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.85)
            }
            .widgetAccentable()
        }
        .widgetURL(Self.addEventURL)
    }
}

#Preview(as: .accessoryCircular) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
    TodayEventsEntry.placeholder
}
