//
//  SummarizeShortcut.swift
//  Dozy AI
//
//  "Dozy 오늘 요약" — 위젯 캐시(TodayEventCache)의 오늘 일정으로 한 줄 요약 + 남은 일정을 읽어준다.
//  EventKit/Google 을 직접 치지 않는 이유: 백그라운드 Siri 호출에서는 권한 다이얼로그나
//  Google 토큰 복원이 불가능하고, 캐시는 이미 4개 소스를 머지한 결과이기 때문.
//

import AppIntents
import Foundation
import SwiftData

struct SummarizeTodayIntent: AppIntent {

    static var title: LocalizedStringResource = "오늘 요약"
    static var description = IntentDescription("오늘 일정을 한 줄로 요약해 알려줍니다.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let context = try AppIntentStore.modelContainer().mainContext

        guard let cached = try AppIntentStore.todayCachedEvents(in: context) else {
            let message = String(localized: "오늘 일정을 아직 불러오지 않았어요. Dozy 를 한 번 열어주세요.")
            return .result(value: message, dialog: "\(message)")
        }

        let events = cached.map { $0.toCalendarEvent() }
        let completedCount = cached.filter(\.isCompleted).count

        // 리마인더는 캐시에 없으므로 빈 배열. 일정 완료 수는 아래 문장에서 직접 읽어준다.
        let headline = try await AppIntentStore.aiService.generateQuickSummary(
            events: events,
            completedTasks: []
        )

        var sentences = [headline]
        if !events.isEmpty {
            sentences.append(String(localized: "\(completedCount)건 완료했어요."))
        }
        let remaining = cached.filter { !$0.isCompleted && $0.endDate > Date() }
        if !remaining.isEmpty {
            let list = remaining.prefix(3).map(Self.spoken).joined(separator: ", ")
            sentences.append(String(localized: "남은 일정: \(list)"))
        }

        let message = sentences.joined(separator: " ")
        return .result(value: message, dialog: "\(message)")
    }

    /// "오후 2:30 팀 미팅" 처럼 읽기 좋은 조각.
    private static func spoken(_ event: TodayEventCache) -> String {
        if event.isAllDay { return event.title }
        let time = event.startDate.formatted(date: .omitted, time: .shortened)
        return "\(time) \(event.title)"
    }
}

// MARK: - Cache → Domain

private extension TodayEventCache {
    /// AIService 입력용 최소 변환. 캐시에 없는 필드는 기본값.
    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: id, calendarId: nil, title: title,
            startDate: startDate, endDate: endDate,
            location: nil, notes: nil, isAllDay: isAllDay,
            calendarName: "Dozy", calendarColorHex: colorHex,
            source: .dozy, priority: 0, isPinned: isPinned,
            category: UserCategory.defaultName
        )
    }
}
