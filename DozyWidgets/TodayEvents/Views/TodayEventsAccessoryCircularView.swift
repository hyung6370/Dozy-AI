//
//  TodayEventsAccessoryCircularView.swift
//  DozyWidgetsExtension
//
//  잠금화면 / StandBy 의 accessoryCircular — 시계 옆 원형 슬롯.
//  "일정 추가" 버튼 역할. 탭하면 CreateQuickEventIntent 가 실행되어
//  메인 앱이 활성화되고 일정 생성 바텀시트가 열린다.
//

import AppIntents
import SwiftUI
import WidgetKit

struct TodayEventsAccessoryCircularView: View {
    let entry: TodayEventsEntry

    var body: some View {
        // Button(intent:) 의 시각은 시스템이 자동으로 잠금화면 위젯 스타일에 맞춰 변형.
        // 별도 widgetURL 이나 Link 없이 탭 → 메인 앱 활성화가 처리됨.
        Button(intent: CreateQuickEventIntent()) {
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
        }
        .buttonStyle(.plain)
    }
}

#Preview(as: .accessoryCircular) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
    TodayEventsEntry.placeholder
}
