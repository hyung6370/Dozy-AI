//
//  SearchQueryIntent.swift
//  Dozy AI
//
//  검색창 자연어 질의의 해석 결과 (#72). "지난주 회의 몇 시간" → 기간 · 키워드 · 집계 종류.
//  모델(온디바이스) · 규칙 해석기 어느 쪽이 만들든 이 형태로 모이고, 수치는 SearchAggregator 가 낸다.
//

import Foundation

struct SearchQueryIntent: Equatable {

    /// 무엇을 셀지. rawValue 는 애널리틱스 · 모델 응답 매핑에 쓴다.
    enum Aggregation: String, Equatable, CaseIterable {
        case none
        case count
        case totalHours = "total_hours"
        case completionRate = "completion_rate"
    }

    /// 누가 해석했는지 — 집계 카드의 엔진 라벨과 애널리틱스에 쓴다.
    enum Source: String, Equatable {
        case onDevice = "on_device"
        case rules

        var label: String {
            switch self {
            case .onDevice: return String(localized: "Apple Intelligence")
            case .rules: return String(localized: "날짜 인식")
            }
        }
    }

    /// [start, end) — end 는 포함하지 않는다.
    struct Period: Equatable {
        var start: Date
        var end: Date
        var label: String
        /// 기간 없이 집계만 물어 "이번 달"을 기본으로 넣은 경우. 해석 칩에 "(기본)"으로 보여 준다.
        var isDefault: Bool = false
    }

    var period: Period?
    /// 일정 제목 · 장소 · 메모에서 찾을 말. 여러 단어면 모두 들어간 일정만.
    var keyword: String?
    /// 사용자 카테고리 이름과 같은 말이 있으면 그 카테고리 일정도 포함한다.
    var categoryHint: String?
    var aggregation: Aggregation = .none
    var source: Source = .rules

    /// 기간이 있으면 기간 검색(목록 + 집계), 없으면 기존 키워드 검색.
    var kind: SearchQueryKind {
        if period == nil { return .keyword }
        return aggregation == .none ? .period : .aggregate
    }

    var keywordTokens: [String] {
        (keyword ?? "")
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}

/// 애널리틱스 `search_query(kind)` 값.
enum SearchQueryKind: String, Equatable, CaseIterable {
    case keyword
    case period
    case aggregate
}

/// 온디바이스 모델이 낸 원재료 (#72). 날짜는 모델이 Date 를 만들지 않고 문자열만 내며, 검증 · 조립은 Swift 가 한다.
/// Data 의 @Generable 응답(iOS 26+)을 이 형태로 옮겨 Domain 에서 병합 · 테스트한다.
struct ModelQueryInterpretation: Equatable {
    /// YYYY-MM-DD
    var startDate: String?
    /// YYYY-MM-DD, 포함
    var endDate: String?
    var keyword: String?
    var category: String?
    var aggregation: SearchQueryIntent.Aggregation
}

extension Calendar {
    /// 주 시작 월요일 고정 (#72 결정) — 한국 로케일 기본(일요일)과 사용자가 말하는 "지난주"가 어긋나지 않게.
    static func mondayFirst(base: Calendar = .current) -> Calendar {
        var cal = base
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 1
        return cal
    }
}
