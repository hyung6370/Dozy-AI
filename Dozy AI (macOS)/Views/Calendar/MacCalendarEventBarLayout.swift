//
//  MacCalendarEventBarLayout.swift
//  Dozy AI (macOS)
//
//  Phase 1 캘린더 고도화 — 주(7일) 단위로 이벤트 바 레이아웃 계산.
//  - 각 이벤트의 startCol/endCol 을 해당 주 내에서 clamp
//  - 겹치지 않는 가장 위 스택 행(row)에 배치 (greedy bin-packing)
//  - maxVisibleRows 초과 시 overflowByCol 에 누적 (+N 표시용)
//

import Foundation

struct MacCalendarEventBar: Identifiable, Equatable {
    let id: String          // event.id + week key
    let event: CalendarEvent
    let startCol: Int       // 0~6
    let endCol: Int         // 0~6
    let stackRow: Int       // 0, 1, 2, ...

    static func == (lhs: MacCalendarEventBar, rhs: MacCalendarEventBar) -> Bool {
        lhs.id == rhs.id && lhs.startCol == rhs.startCol && lhs.endCol == rhs.endCol && lhs.stackRow == rhs.stackRow
    }
}

struct MacCalendarWeekLayout {
    let bars: [MacCalendarEventBar]
    let overflowByCol: [Int: Int]    // 셀 col → 해당 셀에서 숨은 이벤트 수
}

enum MacCalendarBarLayoutEngine {

    /// 주어진 주(7일)와 날짜별 이벤트 맵으로부터 바 레이아웃을 계산.
    /// maxVisibleRows: 한 주에서 보일 수 있는 최대 스택 행 수 (초과는 overflow)
    static func compute(
        weekDates: [Date],
        eventsByDate: [Date: [CalendarEvent]],
        maxVisibleRows: Int = 3
    ) -> MacCalendarWeekLayout {
        guard weekDates.count == 7 else {
            return MacCalendarWeekLayout(bars: [], overflowByCol: [:])
        }

        let cal = Calendar.current

        // 1) 이 주에 등장하는 유니크 이벤트 수집 (id 기준 dedup)
        var seen = Set<String>()
        var weekEvents: [CalendarEvent] = []
        for d in weekDates {
            let key = cal.startOfDay(for: d)
            if let events = eventsByDate[key] {
                for e in events where !seen.contains(e.id) {
                    seen.insert(e.id)
                    weekEvents.append(e)
                }
            }
        }

        // 2) 각 이벤트의 startCol / endCol 계산 (이번 주 내로 clamp)
        var spans: [(event: CalendarEvent, startCol: Int, endCol: Int)] = []
        let weekStart = cal.startOfDay(for: weekDates[0])
        let weekEnd   = cal.startOfDay(for: weekDates[6])

        for event in weekEvents {
            let eventStart = cal.startOfDay(for: event.startDate)
            let eventEnd   = cal.startOfDay(for: event.endDate)

            // 이 주와 겹치지 않으면 스킵
            if eventEnd < weekStart || eventStart > weekEnd { continue }

            let effectiveStart = max(eventStart, weekStart)
            let effectiveEnd   = min(eventEnd, weekEnd)

            // col = days offset from week start
            let startCol = max(0, min(6, cal.dateComponents([.day], from: weekStart, to: effectiveStart).day ?? 0))
            let endCol   = max(0, min(6, cal.dateComponents([.day], from: weekStart, to: effectiveEnd).day ?? 0))

            if startCol > endCol { continue }
            spans.append((event, startCol, endCol))
        }

        // 3) 정렬: 시작 col 빠른 순, 같으면 기간 긴 순 (긴 이벤트가 낮은 row 차지)
        spans.sort {
            if $0.startCol != $1.startCol { return $0.startCol < $1.startCol }
            return ($0.endCol - $0.startCol) > ($1.endCol - $1.startCol)
        }

        // 4) 스택 행 할당 (겹치지 않는 가장 위 row)
        var occupancy: [Int: Set<Int>] = [:]    // row → occupied cols
        var bars: [MacCalendarEventBar] = []
        var overflow: [Int: Int] = [:]

        let weekKey = "\(Int(weekStart.timeIntervalSince1970))"

        for span in spans {
            let cols = Set(span.startCol...span.endCol)

            var placed = false
            for row in 0..<maxVisibleRows {
                let occupied = occupancy[row, default: []]
                if occupied.intersection(cols).isEmpty {
                    occupancy[row, default: []].formUnion(cols)
                    bars.append(MacCalendarEventBar(
                        id: "\(span.event.id)_\(weekKey)",
                        event: span.event,
                        startCol: span.startCol,
                        endCol: span.endCol,
                        stackRow: row
                    ))
                    placed = true
                    break
                }
            }

            if !placed {
                for col in cols {
                    overflow[col, default: 0] += 1
                }
            }
        }

        return MacCalendarWeekLayout(bars: bars, overflowByCol: overflow)
    }
}
