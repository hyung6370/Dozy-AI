//
//  AnalyticsEvent.swift
//  Dozy AI
//
//  애널리틱스 이벤트 정의 (#90). 이벤트 이름 · 파라미터를 타입으로 고정해 문자열이 코드 곳곳에 흩어지지 않게 한다.
//  - 이름 규칙은 Firebase 기준: 영문 소문자 · 숫자 · 밑줄, 글자로 시작, 40자 이하. 파라미터 25개 이하.
//  - 일정 제목 · 메모 · 장소 등 사용자 콘텐츠는 절대 담지 않는다. 종류 · 개수 · 경로 같은 메타데이터만.
//    그래서 파라미터 값은 아래 enum 의 rawValue 나 정수만 받도록 case 를 설계했다.
//  프레임워크 의존 없음 — iOS · macOS 앱과 단위 테스트에서 그대로 쓴다.
//

import Foundation

enum AnalyticsEvent: Equatable {
    /// 앱 실행. 리텐션은 Firebase 자동 `session_start` 로도 보지만, 플랫폼 구분이 확실한 수동 신호를 하나 둔다.
    case appOpened
    /// AI 요약 생성 완료. 어떤 엔진이 실제로 썼는지.
    case summaryGenerated(engine: AIEngineStatus)
    /// 요약 시트를 연 경로.
    case summarySheetOpened(source: SummarySheetSource)
    /// 새 일정 저장 완료(수정은 제외).
    case eventCreated(method: EventInputMethod)
    case sharedCalendarCreated
    case sharedCalendarJoined(via: SharedCalendarJoinVia)
    /// 외부(Apple · Google) 일정을 공유 캘린더로 복사.
    case externalEventMirrored(provider: CalendarSource)
    /// 설정에서 외부 캘린더 연동을 켬.
    case calendarSourceConnected(provider: CalendarSource)
    /// 인사이트 화면 진입 · 기간 변경.
    case insightsOpened(periodDays: Int)
    /// 검색 질의 확정 (#72). 어떤 종류로 해석됐고 누가 해석했는지 — 질의 문장은 보내지 않는다.
    case searchQuery(kind: SearchQueryKind, engine: SearchQueryIntent.Source)

    var name: String {
        switch self {
        case .appOpened:                return "app_opened"
        case .summaryGenerated:         return "summary_generated"
        case .summarySheetOpened:       return "summary_sheet_opened"
        case .eventCreated:             return "event_created"
        case .sharedCalendarCreated:    return "shared_calendar_created"
        case .sharedCalendarJoined:     return "shared_calendar_joined"
        case .externalEventMirrored:    return "external_event_mirrored"
        case .calendarSourceConnected:  return "calendar_source_connected"
        case .insightsOpened:           return "insights_opened"
        case .searchQuery:              return "search_query"
        }
    }

    var parameters: [String: AnalyticsValue] {
        switch self {
        case .appOpened, .sharedCalendarCreated:
            return [:]
        case .summaryGenerated(let engine):
            return ["engine": .string(Self.engineValue(engine))]
        case .summarySheetOpened(let source):
            return ["source": .string(source.rawValue)]
        case .eventCreated(let method):
            return ["method": .string(method.rawValue)]
        case .sharedCalendarJoined(let via):
            return ["via": .string(via.rawValue)]
        case .externalEventMirrored(let provider), .calendarSourceConnected(let provider):
            return ["provider": .string(provider.rawValue)]
        case .insightsOpened(let days):
            return ["period_days": .int(days)]
        case .searchQuery(let kind, let engine):
            return ["kind": .string(kind.rawValue), "engine": .string(engine.rawValue)]
        }
    }

    /// 요약 엔진을 대시보드에서 묶어 보기 좋은 세 값으로 줄인다.
    static func engineValue(_ status: AIEngineStatus) -> String {
        switch status {
        case .onDevice:         return "on_device"
        case .onDeviceFailed:   return "on_device_failed"
        default:                return "local"
        }
    }
}

/// 이벤트 파라미터 값. 문자열은 enum rawValue 만 넘어오도록 호출부를 제한한다.
enum AnalyticsValue: Equatable {
    case string(String)
    case int(Int)
}

/// 사용자 속성 (Firebase user property, 이름 24자 이하).
enum AnalyticsUserProperty: String, CaseIterable {
    /// 켜 둔 외부 캘린더 소스 수 (Dozy 제외).
    case calendarSourceCount = "calendar_source_count"
}

// MARK: - 파라미터 값 enum

/// 새 일정을 만든 방법.
enum EventInputMethod: String, Equatable, CaseIterable {
    case manual
    case naturalLanguage = "natural_language"
    case voice
    case menubar
    case widget
}

enum SummarySheetSource: String, Equatable, CaseIterable {
    case home
    case notification
}

enum SharedCalendarJoinVia: String, Equatable, CaseIterable {
    /// 초대 코드를 직접 입력.
    case code
    /// dozyapp.kr/shared-calendar/join 링크로 열림.
    case link
}

// MARK: - 수집 동의 설정

/// 설정 "사용 통계 전송" 토글. 기본 켜짐 — 익명 사용 통계만 보내고 사용자가 끌 수 있다.
nonisolated enum AnalyticsSettings {
    static let enabledKey = "analytics.isEnabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? true : defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}
