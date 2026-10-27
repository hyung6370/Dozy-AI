//
//  DemoDataSeeder.swift
//  Dozy AI
//
//  DEBUG 전용 샘플 데이터. 앱을 `-seedDemoData` 인자로 실행하면 로컬 SwiftData 의
//  일정 · 완료 · 작업 기록 · 카테고리를 모두 지우고 지난 30일 + 다음 7일치 한국어 샘플로 채운다.
//  App Store 스크린샷 · 데모용. Supabase 에는 올리지 않는다(컨텍스트에 직접 insert).
//
//      xcrun simctl launch <UDID> com.dozy-ai.Dozy-AI -uiTesting -seedDemoData
//

#if DEBUG
import Foundation
import SwiftData

enum DemoDataSeeder {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedDemoData")
    }

    private struct Category { let name: String; let emoji: String; let color: String }
    private static let categories: [Category] = [
        .init(name: "일반", emoji: "📌", color: "#8E8E93"),
        .init(name: "업무", emoji: "💼", color: "#5B6EFF"),
        .init(name: "개인", emoji: "🏠", color: "#FF9F0A"),
        .init(name: "공부", emoji: "📚", color: "#34C759"),
        .init(name: "운동", emoji: "🏃", color: "#FF2D55"),
        .init(name: "데이트", emoji: "💜", color: "#AF52DE"),
    ]
    private static func color(_ name: String) -> String {
        categories.first { $0.name == name }?.color ?? "#8E8E93"
    }

    /// (시작 시·분, 길이 분, 제목, 카테고리, 장소)
    private struct Slot { let hour: Int; let minute: Int; let length: Int; let title: String; let category: String; let location: String? }

    /// 요일별 기본 일정 (1=일 … 7=토)
    private static func slots(for weekday: Int, dayOffset: Int) -> [Slot] {
        var s: [Slot] = []
        let isWeekday = (2...6).contains(weekday)
        if isWeekday { s.append(.init(hour: 9, minute: 30, length: 30, title: "팀 스탠드업", category: "업무", location: nil)) }
        if [2, 4, 6].contains(weekday) { s.append(.init(hour: 7, minute: 30, length: 60, title: "헬스", category: "운동", location: "피트니스 센터")) }
        if weekday == 2 { s.append(.init(hour: 14, minute: 0, length: 90, title: "스프린트 회의", category: "업무", location: "회의실 A")) }
        if weekday == 4 { s.append(.init(hour: 14, minute: 0, length: 60, title: "디자인 리뷰", category: "업무", location: nil)) }
        if weekday == 6 { s.append(.init(hour: 17, minute: 0, length: 60, title: "주간 회고", category: "업무", location: nil)) }
        if [3, 5].contains(weekday) { s.append(.init(hour: 19, minute: 0, length: 90, title: "토익 공부", category: "공부", location: "스터디 카페")) }
        if weekday == 7 { s.append(.init(hour: 14, minute: 0, length: 240, title: "데이트", category: "데이트", location: "성수동")) }
        if weekday == 1 { s.append(.init(hour: 15, minute: 0, length: 120, title: "사이드 프로젝트", category: "개인", location: nil)) }
        // 가끔 끼는 일정
        switch dayOffset % 9 {
        case 1: s.append(.init(hour: 12, minute: 0, length: 60, title: "점심 약속", category: "개인", location: "을지로"))
        case 4: s.append(.init(hour: 20, minute: 30, length: 60, title: "독서", category: "공부", location: nil))
        case 7: s.append(.init(hour: 18, minute: 30, length: 60, title: "장보기", category: "개인", location: "마트"))
        default: break
        }
        return s
    }

    /// 오늘은 스크린샷에 맞춰 고정 (진행 중 일정 포함)
    private static let todaySlots: [Slot] = [
        .init(hour: 7, minute: 30, length: 60, title: "헬스", category: "운동", location: "피트니스 센터"),
        .init(hour: 9, minute: 0, length: 30, title: "팀 스탠드업", category: "업무", location: nil),
        .init(hour: 10, minute: 0, length: 30, title: "이메일 정리", category: "업무", location: nil),
        .init(hour: 11, minute: 0, length: 60, title: "디자인 리뷰", category: "업무", location: "회의실 B"),
        .init(hour: 13, minute: 30, length: 120, title: "사이드 프로젝트", category: "개인", location: nil),
        .init(hour: 16, minute: 30, length: 60, title: "치과 예약", category: "개인", location: "강남역 치과"),
        .init(hour: 19, minute: 0, length: 90, title: "토익 공부", category: "공부", location: "스터디 카페"),
    ]

    @MainActor
    static func seed(in container: ModelContainer) {
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 기존 로컬 데이터 제거
        try? context.delete(model: DozyEvent.self)
        try? context.delete(model: EventCompletion.self)
        try? context.delete(model: WorkLog.self)
        try? context.delete(model: UserCategory.self)
        try? context.delete(model: TodayEventCache.self)

        for (i, c) in categories.enumerated() {
            context.insert(UserCategory(name: c.name, emoji: c.emoji, colorHex: c.color, order: i))
        }

        var titlesByDay: [Int: [String]] = [:]
        var categoryByDay: [Int: String] = [:]
        for offset in -30...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = cal.component(.weekday, from: day)
            let daySlots = offset == 0 ? todaySlots : slots(for: weekday, dayOffset: abs(offset))
            var titles: [String] = []
            var counts: [String: Int] = [:]
            for (j, slot) in daySlots.enumerated() {
                let start = cal.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day)!
                let end = start.addingTimeInterval(TimeInterval(slot.length * 60))
                // 과거는 대부분 완료, 가끔 하나 빠뜨림 (완료율 ~85%)
                let done = offset < 0 ? ((abs(offset) + j) % 7 != 3) : (offset == 0 && end < Date())
                let event = DozyEvent(title: slot.title, startDate: start, endDate: end,
                                      location: slot.location, colorHex: color(slot.category),
                                      category: slot.category)
                event.isCompleted = done
                context.insert(event)
                titles.append(slot.title)
                counts[slot.category, default: 0] += 1
            }
            titlesByDay[offset] = titles
            categoryByDay[offset] = counts.max { $0.value < $1.value }?.key ?? "일반"
        }

        // 워크샵: 이번 주 목요일(또는 이틀 뒤) 하루 일정
        if let workshop = cal.date(byAdding: .day, value: 2, to: today) {
            let start = cal.date(bySettingHour: 10, minute: 0, second: 0, of: workshop)!
            let e = DozyEvent(title: "워크샵 - 경기도 가평", startDate: start, endDate: start.addingTimeInterval(8 * 3600),
                              location: "경기도 가평", notes: "팀 워크샵 · 1박 2일", colorHex: color("업무"), category: "업무")
            e.isPinned = true
            context.insert(e)
        }

        // 기본 공유 캘린더가 있으면 가족 일정 몇 개 (파트너 소유 포함) — 공유 화면 데모용
        if let sharedID = UserDefaults.standard.string(forKey: "active_shared_calendar_id"), !sharedID.isEmpty {
            let partner = "demo-partner"
            let family: [(Int, Int, Int, Int, String, String?, String?)] = [  // (dayOffset, hour, minute, length, title, location, ownerID)
                (0, 19, 30, 90, "가족 저녁 식사", "집", partner),
                (1, 10, 0, 60, "병원 예약", "서울대병원", nil),
                (1, 18, 0, 120, "엄마 생신 🎂", "본가", partner),
                (2, 16, 0, 60, "아이 학원 상담", "학원", partner),
                (4, 11, 0, 300, "주말 나들이", "한강공원", partner),
                (5, 15, 0, 90, "장보기", "마트", nil),
                (-2, 20, 0, 60, "영화 보기", "CGV", partner),
                (-5, 12, 0, 90, "가족 점심", "을지로", nil),
            ]
            for (offset, hour, minute, length, title, location, owner) in family {
                guard let day = cal.date(byAdding: .day, value: offset, to: today),
                      let start = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
                let e = DozyEvent(title: title, startDate: start, endDate: start.addingTimeInterval(TimeInterval(length * 60)),
                                  location: location, colorHex: "#FF6B9D", category: "개인",
                                  sharedCalendarID: sharedID, ownerID: owner)
                e.isCompleted = offset < 0
                context.insert(e)
            }
        }

        // 지난 29일 작업 기록 (인사이트 생산성 추이 · 카테고리 분포)
        let summaries = [
            "오전 회의를 빠르게 마치고 오후에 집중 작업 시간을 확보했어요.",
            "계획한 일정을 대부분 지켰어요. 저녁 공부 루틴이 잘 유지되고 있어요.",
            "운동으로 하루를 시작해 컨디션이 좋았어요. 회의가 조금 길어졌어요.",
            "주말 일정이 여유로웠어요. 사이드 프로젝트에 집중할 수 있었어요.",
        ]
        for offset in -29...(-1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let log = WorkLog(date: day)
            log.rawEventTitles = titlesByDay[offset] ?? []
            log.rawEventDetails = log.rawEventTitles
            log.category = categoryByDay[offset] ?? "일반"
            log.aiSummary = summaries[abs(offset) % summaries.count]
            log.highlights = Array(log.rawEventTitles.prefix(3))
            log.nextActions = ["내일 일정 미리 확인", "집중 시간 블록 잡기"]
            let weekday = cal.component(.weekday, from: day)
            let base = (2...6).contains(weekday) ? 0.80 : 0.68
            let wobble = Double((abs(offset) * 37) % 17) / 100.0 - 0.08   // -0.08 ~ +0.08
            log.productivityScore = min(0.96, max(0.55, base + wobble))
            context.insert(log)
        }

        try? context.save()
    }
}
#endif
