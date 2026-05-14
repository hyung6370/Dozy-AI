//
//  TodayEventsEntry.swift
//  DozyWidgetsExtension
//
//  Created by Hyungjun KIM on 5/14/26.
//

import WidgetKit
import Foundation

struct TodayEventsEntry: TimelineEntry {
    
    /// OS가 이 entry 를 표시해야 할 시각
    let date: Date
    
    /// 표시할 일정들. 이미 시간순 정렬된 상태.
    /// 위젯이 매번 SwiftData 를 쿼리하지 않도록 미리 snapshot 으로 변환된 형태.
    let events: [WidgetEventSnapshot]
    
    /// "오늘 완료된 일정 / 전체" 카운트 — small/medium 의 메타 라벨.
    let completedCount: Int
    let totalCount: Int
    
    /// SwiftData container 접근 실패 등 비정상 상태 표시용. 일반 placeholder 와 구분.
    let errorMessage: String?

    /// 이번 달에서 일정이 있는 날짜들 (startOfDay 기준).
    /// systemLarge 의 미니 월간 캘린더에서 "dot 찍을 날" 판별용.
    let monthEventDates: Set<Date>

    // MARK: - Factories

    static let placeholder: TodayEventsEntry = .init(
        date: Date(),
        events: [],
        completedCount: 0,
        totalCount: 0,
        errorMessage: nil,
        monthEventDates: []
    )
    
    /// Preview / snapshot 전용 샘플
    static let sampleWithEvents: TodayEventsEntry = {
        let now = Date()
        let cal = Calendar.current
        let samples: [WidgetEventSnapshot] = [
            .init(
                id: UUID().uuidString,
                title: "스탠드업 미팅",
                start: cal.date(byAdding: .minute, value: 30, to: now)!,
                end:   cal.date(byAdding: .minute, value: 60, to: now)!,
                isAllDay: false,
                colorHex: "#4A90E2",
                isCompleted: false,
                isPinned: false
            ),
            .init(
                id: UUID().uuidString,
                title: "분기 리포트 작성",
                start: cal.date(byAdding: .hour, value: 2, to: now)!,
                end:   cal.date(byAdding: .hour, value: 4, to: now)!,
                isAllDay: false,
                colorHex: "#FF6B9D",
                isCompleted: false,
                isPinned: true
            ),
            .init(
                id: UUID().uuidString,
                title: "런치 & 1:1",
                start: cal.date(byAdding: .hour, value: 6, to: now)!,
                end:   cal.date(byAdding: .hour, value: 7, to: now)!,
                isAllDay: false,
                colorHex: "#50C878",
                isCompleted: false,
                isPinned: false
            ),
        ]
        // sample 의 monthEventDates — 오늘, 오늘+3일, 오늘+7일, 오늘-2일 등 흩뿌려서 캘린더가
        // 비어보이지 않게 한다. 실제 production 에선 DataSource 가 채움.
        let scattered: [Date] = [-5, -2, 0, 3, 7, 12, 15, 18].compactMap {
            cal.date(byAdding: .day, value: $0, to: now).map { cal.startOfDay(for: $0) }
        }
        return .init(
            date: now,
            events: samples,
            completedCount: 2,
            totalCount: 6,
            errorMessage: nil,
            monthEventDates: Set(scattered)
        )
    }()
}

/// SwiftData 의 DozyEvent 를 위젯이 표시하기 쉬운 immutable struct 로 변환한 snapshot.
/// `Sendable` 로 두면 TimelineProvider 의 async 경계 넘기기 편함.
struct WidgetEventSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let colorHex: String
    let isCompleted: Bool
    let isPinned: Bool
    
    var timeRangeString: String {
        if isAllDay { return String(localized: "종일") }
        let fmt = DateFormatter()
        fmt.locale = .current
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start)) ~ \(fmt.string(from: end))"
    }
}
