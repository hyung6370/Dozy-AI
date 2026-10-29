//
//  QueryRuleParser.swift
//  Dozy AI
//
//  자연어 질의 규칙 해석기 (#72). 상대 기간 사전 + 집계 표현 + 나머지는 키워드.
//  Apple Intelligence 가 없는 기기(iOS 26 미만 · 꺼 둔 기기)의 유일한 경로이고, 모델 결과의 기간도 여기서 교차 검증한다.
//  NSDataDetector 는 "지난주" 같은 범위 표현을 못 잡아서 사전 방식을 쓴다. 프레임워크 의존 없음.
//

import Foundation

enum QueryRuleParser {

    // MARK: - 진입점

    /// 두 단어 이상이면 자연어 질의일 수 있다 — 모델 호출 · 진행 표시 기준. 한 단어("회의")는 키워드 검색.
    static func isMultiWord(_ text: String) -> Bool {
        text.split(whereSeparator: \.isWhitespace).count >= 2
    }

    static func parse(
        _ text: String,
        referenceDate: Date,
        categories: [String],
        calendar base: Calendar = .current
    ) -> SearchQueryIntent {
        let cal = Calendar.mondayFirst(base: base)
        var working = text.lowercased()

        var period: SearchQueryIntent.Period?
        if let found = findPeriod(in: working, referenceDate: referenceDate, calendar: cal) {
            period = found.period
            working = removing(found.range, from: working)
        }

        var aggregation = SearchQueryIntent.Aggregation.none
        if let found = findAggregation(in: working) {
            aggregation = found.aggregation
            working = removing(found.range, from: working)
        }

        let keyword = extractKeyword(from: working)
        var intent = SearchQueryIntent(
            period: period,
            keyword: keyword,
            categoryHint: categoryHint(for: keyword, in: categories),
            aggregation: aggregation,
            source: .rules
        )
        applyDefaultPeriod(to: &intent, referenceDate: referenceDate, calendar: cal)
        return intent
    }

    /// 기간 없이 집계만 물으면 이번 달 (#72 결정).
    static func applyDefaultPeriod(to intent: inout SearchQueryIntent, referenceDate: Date, calendar base: Calendar = .current) {
        guard intent.period == nil, intent.aggregation != .none else { return }
        let cal = Calendar.mondayFirst(base: base)
        guard let month = cal.dateInterval(of: .month, for: referenceDate) else { return }
        intent.period = .init(start: month.start, end: month.end, label: String(localized: "이번 달"), isDefault: true)
    }

    // MARK: - 모델 결과 병합

    /// 모델 결과를 규칙 결과와 합친다.
    /// - 기간: 사전에 있는 표현은 규칙이 정확하므로 규칙 우선, 없을 때만 모델 날짜(검증 통과 시)
    /// - 키워드: 모델이 문장에 없는 말을 지어냈으면 버리고 규칙 키워드
    /// - 카테고리: 후보 목록에 있는 이름만
    static func merge(
        model: ModelQueryInterpretation,
        rules: SearchQueryIntent,
        text: String,
        referenceDate: Date,
        categories: [String],
        calendar base: Calendar = .current
    ) -> SearchQueryIntent {
        let cal = Calendar.mondayFirst(base: base)
        let lowered = text.lowercased()

        var intent = rules
        intent.source = .onDevice

        if rules.period == nil || rules.period?.isDefault == true,
           let modelPeriod = period(fromModelStart: model.startDate, end: model.endDate, calendar: cal) {
            intent.period = modelPeriod
        }

        if model.aggregation != .none { intent.aggregation = model.aggregation }

        if let keyword = model.keyword?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !keyword.isEmpty,
           keyword.split(whereSeparator: \.isWhitespace).allSatisfy({ lowered.contains($0) }) {
            intent.keyword = keyword
        }

        if let category = model.category,
           let matched = categories.first(where: { $0.lowercased() == category.lowercased() }) {
            intent.categoryHint = matched
        } else {
            intent.categoryHint = categoryHint(for: intent.keyword, in: categories)
        }

        applyDefaultPeriod(to: &intent, referenceDate: referenceDate, calendar: cal)
        return intent
    }

    /// 모델이 낸 "YYYY-MM-DD" 두 개 → 기간. 형식 불량 · 역순 · 3년 초과는 버린다.
    static func period(fromModelStart start: String?, end: String?, calendar cal: Calendar) -> SearchQueryIntent.Period? {
        guard let start, let startDay = day(from: start, calendar: cal) else { return nil }
        let endDay = end.flatMap { day(from: $0, calendar: cal) } ?? startDay
        guard endDay >= startDay,
              let endExclusive = cal.date(byAdding: .day, value: 1, to: endDay),
              let limit = cal.date(byAdding: .year, value: 3, to: startDay),
              endExclusive <= limit else { return nil }
        let style = Date.FormatStyle.dateTime.month().day()
        let label = startDay == endDay
            ? startDay.formatted(style)
            : "\(startDay.formatted(style)) – \(endDay.formatted(style))"
        return .init(start: startDay, end: endExclusive, label: label)
    }

    private static func day(from string: String, calendar cal: Calendar) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
        guard let date = cal.date(from: comps),
              cal.component(.month, from: date) == parts[1] else { return nil }   // 2월 30일 같은 값 거름
        return cal.startOfDay(for: date)
    }

    // MARK: - 기간

    private enum PeriodRule {
        case today, yesterday
        case thisWeek, lastWeek, nextWeek
        case thisMonth, lastMonth, nextMonth
        case thisYear, lastYear
        case lastDays, lastWeeks, lastMonths      // 숫자 캡처 1개
        case fixedDays(Int), fixedMonths(Int)     // "최근 일주일" · "최근 한 달"
    }

    /// 순서가 중요하다 — 숫자 표현을 "지난주" · "지난달"보다 먼저 본다.
    private static let periodRules: [(pattern: String, rule: PeriodRule)] = [
        (#"(?:최근|지난)\s*(\d+)\s*일"#, .lastDays),
        (#"(?:최근|지난)\s*(\d+)\s*주(?:일)?"#, .lastWeeks),
        (#"(?:최근|지난)\s*(\d+)\s*(?:개월|달)"#, .lastMonths),
        (#"(?:last|past)\s+(\d+)\s+days?"#, .lastDays),
        (#"(?:last|past)\s+(\d+)\s+weeks?"#, .lastWeeks),
        (#"(?:last|past)\s+(\d+)\s+months?"#, .lastMonths),
        (#"최근\s*(?:일주일|한\s*주)"#, .fixedDays(7)),
        (#"최근\s*한\s*달"#, .fixedMonths(1)),
        (#"오늘|today"#, .today),
        (#"어제|yesterday"#, .yesterday),
        (#"이번\s*주|금주|this\s+week"#, .thisWeek),
        (#"(?:지난|저번)\s*주|last\s+week"#, .lastWeek),
        (#"다음\s*주|next\s+week"#, .nextWeek),
        (#"이번\s*달|이번\s*월|this\s+month"#, .thisMonth),
        (#"(?:지난|저번)\s*달|지난\s*월|last\s+month"#, .lastMonth),
        (#"다음\s*달|next\s+month"#, .nextMonth),
        (#"올해|올\s*해|금년|this\s+year"#, .thisYear),
        (#"작년|지난\s*해|last\s+year"#, .lastYear),
    ]

    static func findPeriod(
        in text: String, referenceDate ref: Date, calendar cal: Calendar
    ) -> (period: SearchQueryIntent.Period, range: Range<String.Index>)? {
        for (pattern, rule) in periodRules {
            guard let match = firstMatch(pattern, in: text) else { continue }
            let number = match.captures.first.flatMap { Int($0) }
            guard let period = resolve(rule, number: number, referenceDate: ref, calendar: cal) else { continue }
            return (period, match.range)
        }
        return nil
    }

    private static func resolve(_ rule: PeriodRule, number: Int?, referenceDate ref: Date, calendar cal: Calendar) -> SearchQueryIntent.Period? {
        let today = cal.startOfDay(for: ref)
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return nil }

        func interval(_ component: Calendar.Component, offset: Int, label: String) -> SearchQueryIntent.Period? {
            guard let anchor = cal.date(byAdding: component, value: offset, to: ref),
                  let iv = cal.dateInterval(of: component, for: anchor) else { return nil }
            return .init(start: iv.start, end: iv.end, label: label)
        }
        func lastDays(_ n: Int, label: String) -> SearchQueryIntent.Period? {
            guard let start = cal.date(byAdding: .day, value: -(n - 1), to: today) else { return nil }
            return .init(start: start, end: tomorrow, label: label)
        }
        func lastMonths(_ n: Int, label: String) -> SearchQueryIntent.Period? {
            guard let back = cal.date(byAdding: .month, value: -n, to: today),
                  let start = cal.date(byAdding: .day, value: 1, to: back) else { return nil }
            return .init(start: start, end: tomorrow, label: label)
        }

        switch rule {
        case .today:     return .init(start: today, end: tomorrow, label: String(localized: "오늘"))
        case .yesterday: return interval(.day, offset: -1, label: String(localized: "어제"))
        case .thisWeek:  return interval(.weekOfYear, offset: 0, label: String(localized: "이번 주"))
        case .lastWeek:  return interval(.weekOfYear, offset: -1, label: String(localized: "지난주"))
        case .nextWeek:  return interval(.weekOfYear, offset: 1, label: String(localized: "다음 주"))
        case .thisMonth: return interval(.month, offset: 0, label: String(localized: "이번 달"))
        case .lastMonth: return interval(.month, offset: -1, label: String(localized: "지난달"))
        case .nextMonth: return interval(.month, offset: 1, label: String(localized: "다음 달"))
        case .thisYear:  return interval(.year, offset: 0, label: String(localized: "올해"))
        case .lastYear:  return interval(.year, offset: -1, label: String(localized: "작년"))
        case .lastDays:
            guard let n = number, (1...3650).contains(n) else { return nil }
            return lastDays(n, label: String(localized: "최근 \(n)일"))
        case .lastWeeks:
            guard let n = number, (1...520).contains(n) else { return nil }
            return lastDays(n * 7, label: String(localized: "최근 \(n)주"))
        case .lastMonths:
            guard let n = number, (1...120).contains(n) else { return nil }
            return lastMonths(n, label: String(localized: "최근 \(n)개월"))
        case .fixedDays(let n):
            return lastDays(n, label: String(localized: "최근 \(n)일"))
        case .fixedMonths(let n):
            return lastMonths(n, label: String(localized: "최근 \(n)개월"))
        }
    }

    // MARK: - 집계

    /// 순서가 중요하다 — "how many hours" 를 "how many" 보다 먼저.
    private static let aggregationRules: [(pattern: String, aggregation: SearchQueryIntent.Aggregation)] = [
        (#"완료율|달성률|완료\s*비율|얼마나\s*완료|completion\s*rate"#, .completionRate),
        (#"몇\s*시간|총\s*시간|시간\s*합계|얼마나\s*(?:썼|걸렸|보냈)|how\s+many\s+hours|how\s+long|how\s+much\s+time|total\s+hours"#, .totalHours),
        (#"몇\s*번|몇\s*회|몇\s*개|횟수|how\s+many(?:\s+times)?|how\s+often"#, .count),
    ]

    static func findAggregation(in text: String) -> (aggregation: SearchQueryIntent.Aggregation, range: Range<String.Index>)? {
        for (pattern, aggregation) in aggregationRules {
            if let match = firstMatch(pattern, in: text) { return (aggregation, match.range) }
        }
        return nil
    }

    // MARK: - 키워드

    private static let stopWords: Set<String> = [
        "일정", "약속", "스케줄", "동안", "총", "내가", "나", "제가", "좀", "다", "전부", "모두", "시간", "번", "개", "몇", "얼마나",
        "how", "many", "much", "long", "did", "do", "does", "i", "my", "me", "the", "a", "an", "in", "on", "of",
        "for", "have", "had", "spend", "spent", "time", "times", "hours", "hour", "event", "events", "was", "were",
        "what", "is", "are", "there", "with", "at", "to",
    ]

    /// 동사 · 어미 덩어리 ("했지", "썼어?", "있었나", "알려줘") — 키워드가 아니다.
    private static let verbPattern = #"^(?:했|썼|쓴|있었|있|잡혔|잡힌|됐|갔|알려|보여|하는)"#

    /// 토큰 끝 조사 — "의"는 "회의"를 깨므로 넣지 않는다.
    private static let particles = ["에서는", "에서", "에는", "으로", "에", "은", "는", "을", "를", "도", "랑", "과", "와"]

    static func extractKeyword(from text: String) -> String? {
        let tokens = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(.init(charactersIn: "-")))
            .filter { !$0.isEmpty }
            .compactMap { token -> String? in
                if stopWords.contains(token) { return nil }
                if token.range(of: verbPattern, options: .regularExpression) != nil { return nil }
                var t = token
                if let particle = particles.first(where: { t.hasSuffix($0) && t.count > $0.count + 1 }) {
                    t.removeLast(particle.count)
                }
                return stopWords.contains(t) ? nil : t
            }
        return tokens.isEmpty ? nil : tokens.joined(separator: " ")
    }

    static func categoryHint(for keyword: String?, in categories: [String]) -> String? {
        guard let keyword else { return nil }
        let tokens = Set(keyword.lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
        return categories.first { tokens.contains($0.lowercased()) }
    }

    // MARK: - 정규식 도우미

    private static func firstMatch(_ pattern: String, in text: String) -> (range: Range<String.Index>, captures: [String])? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, options: [], range: ns),
              let range = Range(m.range, in: text) else { return nil }
        let captures = (1..<m.numberOfRanges).compactMap { i -> String? in
            guard let r = Range(m.range(at: i), in: text) else { return nil }
            return String(text[r])
        }
        return (range, captures)
    }

    private static func removing(_ range: Range<String.Index>, from text: String) -> String {
        var copy = text
        copy.replaceSubrange(range, with: " ")
        return copy
    }
}
