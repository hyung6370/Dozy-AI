//
//  TodayEventsSmallView.swift
//  DozyWidgetsExtension
//
//  Created by Hyungjun KIM on 5/14/26.
//

import SwiftUI
import WidgetKit

struct TodayEventsSmallView: View {
    let entry: TodayEventsEntry

    /// 일정 한 건의 상태 — 진행 중(.current) / 다음 예정(.next) / 그 외(nil).
    private enum EventStatus {
        case current
        case next
    }

    /// 위젯에 표시할 일정 — 끝나지 않은 일정 (진행 중 + 예정) 중 시간순 최대 2개.
    /// 종일 일정은 "오늘 하루 종일" 이라 HH:mm 비교가 무의미 — 무조건 표시 대상.
    private var visibleEvents: [WidgetEventSnapshot] {
        let now = entry.date
        return Array(entry.events.filter { $0.isAllDay || $0.end > now }.prefix(2))
    }

    /// 각 visible 일정에 "현재" / "다음" 라벨을 매핑.
    /// - 종일 일정은 오늘 하루 종일 진행 중 → .current.
    /// - 시간 일정은 진행 중인 것 1개에 .current, 다음 예정 1개에 .next (독립적).
    /// - 해당 일정이 없으면 키 자체가 없음 → row 에 배지 안 그려짐.
    private var statusByID: [String: EventStatus] {
        let now = entry.date
        var map: [String: EventStatus] = [:]

        for ev in visibleEvents where ev.isAllDay {
            map[ev.id] = .current
        }

        let timeOnly = visibleEvents.filter { !$0.isAllDay }
        if let current = timeOnly.first(where: { $0.start <= now && $0.end > now }) {
            map[current.id] = .current
        }
        if let next = timeOnly.first(where: { $0.start > now }) {
            map[next.id] = .next
        }
        return map
    }

    /// 오늘 날짜 헤더 — 일정 리스트 위에 표시. ko: "5월 14일 (수)" / en: format catalog 에 맞춤.
    private var todayDateTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = String(localized: "M월 d일 (E)")
        return f.string(from: entry.date)
    }

    /// HH:mm 만 — small 위젯은 공간이 좁아 시작 시각만.
    private func shortTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = .current
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 상단 — 오늘 날짜 + Dozy 로고. 현재/다음 라벨은 각 일정 row 안쪽에 inline 표시.
            HStack {
                Text(verbatim: todayDateTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image("Dozy-AI-40x40")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if visibleEvents.isEmpty {
                Spacer(minLength: 0)
                Text("남은 일정 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                // 각 row 가 남은 vertical 공간을 균등하게 나눠 갖도록 — 행 자체가
                // expand → 컬러 바와 카드 영역이 함께 늘어남. 중간 빈 여백 사라짐.
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleEvents, id: \.id) { ev in
                        eventRow(ev, status: statusByID[ev.id])
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            // 하단 — 완료 카운트.
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(verbatim: "\(entry.completedCount) / \(entry.totalCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    /// 한 일정 = 좌측 컬러 바 + (시간 + 상태 배지) + 제목.
    /// row 자체가 `maxHeight: .infinity` 로 expand → 부모 VStack 안에서 여러 row 가
    /// 균등하게 vertical 공간을 나눠 가짐. 컬러 바 height 는 row 와 함께 늘어남.
    /// 콘텐츠는 `Spacer(minLength: 0)` 로 상단 정렬 유지.
    private func eventRow(_ ev: WidgetEventSnapshot, status: EventStatus?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: ev.colorHex) ?? .accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: ev.isAllDay ? String(localized: "종일") : shortTime(ev.start))
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let status {
                        statusBadge(status)
                    }
                }
                Text(ev.title)
                    .font(.caption.weight(ev.isCompleted ? .regular : .semibold))
                    .foregroundStyle(ev.isCompleted ? .secondary : .primary)
                    .strikethrough(ev.isCompleted, color: .secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// "현재" / "다음" capsule 배지 — 일정 row 안의 시간 옆에 inline 표시.
    @ViewBuilder
    private func statusBadge(_ status: EventStatus) -> some View {
        switch status {
        case .current:
            Text("현재")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.green))
        case .next:
            Text("다음")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.accentColor))
        }
    }
}

#Preview(as: .systemSmall) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry.sampleWithEvents
}
