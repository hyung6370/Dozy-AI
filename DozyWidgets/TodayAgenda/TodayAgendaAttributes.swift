//
//  TodayAgendaAttributes.swift
//  DozyWidgetsExtension
//
//  "오늘 아젠다" Live Activity 의 ActivityAttributes + ContentState.
//  메인 앱(시작·갱신)과 위젯 extension(렌더링) 양쪽에 컴파일된다. ActivityKit 은 iOS 전용이라
//  macOS 타깃에는 넣지 않는다.
//
//  ContentState 는 Codable/Hashable 이어야 하고 4KB 안에 들어와야 하므로 제목·시각·색만 담는다.
//  카운트다운·진행 바는 start/end 를 timerInterval 뷰에 넘겨 시스템이 그린다 — 앱이 갱신하지 않아도 움직인다.
//  앱 타깃은 기본 격리가 MainActor 라 Codable/Hashable 값 타입은 nonisolated 로 선언한다 (ActivityKit 이 비동기로 인코딩).
//

#if os(iOS)
import ActivityKit
import Foundation

nonisolated struct TodayAgendaAttributes: ActivityAttributes {

    nonisolated struct Entry: Codable, Hashable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let colorHex: String
    }

    nonisolated struct ContentState: Codable, Hashable {
        /// 지금 진행 중인 일정. 없으면 nil.
        let current: Entry?
        /// 다음에 시작할 일정. 없으면 nil (current 가 마지막).
        let next: Entry?
        let remainingCount: Int
        let completedCount: Int
        let totalCount: Int
    }

    /// 액티비티를 만든 날 (자정 넘김 판별·중복 방지 식별용).
    let dayKey: String
}

// MARK: - Domain ↔ ContentState

nonisolated extension TodayAgendaAttributes.Entry {
    init(_ entry: TodayAgendaEntry) {
        self.init(id: entry.id, title: entry.title, start: entry.start, end: entry.end, colorHex: entry.colorHex)
    }
}

nonisolated extension TodayAgendaAttributes.ContentState {
    init(_ snapshot: TodayAgendaSnapshot) {
        self.init(
            current: snapshot.current.map(TodayAgendaAttributes.Entry.init),
            next: snapshot.next.map(TodayAgendaAttributes.Entry.init),
            remainingCount: snapshot.remainingCount,
            completedCount: snapshot.completedCount,
            totalCount: snapshot.totalCount
        )
    }

    /// 화면에 크게 보여줄 일정 — 진행 중이 있으면 그것, 아니면 다음 일정.
    var focus: TodayAgendaAttributes.Entry? { current ?? next }

    /// 액티비티 탭 시 열 deep link. 포커스 일정 상세, 없으면 캘린더 탭.
    var deepLinkURL: URL? {
        if let id = focus?.id, !id.isEmpty {
            var components = URLComponents()
            components.scheme = "dozy-ai"
            components.host = "event-detail"
            components.queryItems = [URLQueryItem(name: "id", value: id)]
            return components.url
        }
        return URL(string: "dozy-ai://calendar")
    }
}
#endif
