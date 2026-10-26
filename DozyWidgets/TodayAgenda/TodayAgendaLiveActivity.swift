//
//  TodayAgendaLiveActivity.swift
//  DozyWidgetsExtension
//
//  "오늘 아젠다" Live Activity 렌더링 — 잠금화면 배너 + 다이나믹 아일랜드(compact · minimal · expanded).
//
//  설계
//  - 앱이 갱신하지 않아도 움직여야 하므로 카운트다운·진행 바는 전부 timerInterval 뷰로 그린다.
//  - current(진행 중)와 next(다음)를 동시에 보여 준다. current 가 끝나도 next 카운트다운은 계속 가므로
//    앱이 그 순간 떠 있지 않아도 잠금화면 정보가 틀리지 않는다.
//  - staleDate 를 넘기면(isStale) 흐리게 + "앱을 열어 갱신" 안내.
//  - 완료 체크는 LiveActivityIntent(ToggleEventCompletionIntent) — 앱 프로세스에서 토글 후 액티비티까지 갱신.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct TodayAgendaLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayAgendaAttributes.self) { context in
            TodayAgendaLockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color(.secondarySystemBackground).opacity(0.85))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(context.state.deepLinkURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image("MenuBarIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text(context.state.current != nil ? "진행 중" : "다음 일정")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let focus = context.state.focus {
                        TodayAgendaTimerText(entry: focus, isCurrent: context.state.current != nil)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(hex: focus.colorHex))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let focus = context.state.focus {
                        Text(focus.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TodayAgendaExpandedBottom(state: context.state, isStale: context.isStale)
                }
            } compactLeading: {
                if let focus = context.state.focus {
                    Circle()
                        .fill(Color(hex: focus.colorHex))
                        .frame(width: 10, height: 10)
                        .padding(.leading, 2)
                } else {
                    Image("MenuBarIcon").resizable().scaledToFit().frame(width: 14, height: 14)
                }
            } compactTrailing: {
                if let focus = context.state.focus {
                    TodayAgendaTimerText(entry: focus, isCurrent: context.state.current != nil)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: 52)
                }
            } minimal: {
                if let focus = context.state.focus {
                    Circle()
                        .fill(Color(hex: focus.colorHex))
                        .frame(width: 10, height: 10)
                } else {
                    Image("MenuBarIcon").resizable().scaledToFit().frame(width: 12, height: 12)
                }
            }
            .widgetURL(context.state.deepLinkURL)
            .keylineTint(context.state.focus.map { Color(hex: $0.colorHex) } ?? .accentColor)
        }
    }
}

// MARK: - 잠금화면

private struct TodayAgendaLockScreenView: View {
    let state: TodayAgendaAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("MenuBarIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("오늘 일정")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(verbatim: "\(state.completedCount) / \(state.totalCount)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let current = state.current {
                TodayAgendaEntryRow(entry: current, label: String(localized: "진행 중"), isCurrent: true, showCheck: true)
                ProgressView(timerInterval: current.start...current.end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(Color(hex: current.colorHex))
                    .progressViewStyle(.linear)
            }

            if let next = state.next {
                TodayAgendaEntryRow(entry: next, label: String(localized: "다음 일정"), isCurrent: false, showCheck: state.current == nil)
            }

            if isStale {
                Text("앱을 열어 최신 일정으로 갱신하세요")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .opacity(isStale ? 0.6 : 1)
    }
}

/// 일정 1줄 — 색 바 + 제목/시각 + 타이머 (+ 완료 체크).
private struct TodayAgendaEntryRow: View {
    let entry: TodayAgendaAttributes.Entry
    let label: String
    let isCurrent: Bool
    let showCheck: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: entry.colorHex))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: entry.colorHex))
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: TodayAgendaFormat.timeRange(entry.start, entry.end))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            TodayAgendaTimerText(entry: entry, isCurrent: isCurrent)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(isCurrent ? Color(hex: entry.colorHex) : .primary)

            if showCheck {
                Button(intent: ToggleEventCompletionIntent(eventID: entry.id, eventDate: entry.start)) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(Color(hex: entry.colorHex))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("일정 완료"))
            }
        }
    }
}

/// expanded 하단 — 진행 바 + 다음 일정 + 남은 수 + 완료 체크.
private struct TodayAgendaExpandedBottom: View {
    let state: TodayAgendaAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let current = state.current {
                ProgressView(timerInterval: current.start...current.end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(Color(hex: current.colorHex))
                    .progressViewStyle(.linear)
            }
            HStack(spacing: 8) {
                if let next = state.next, state.current != nil {
                    Text(verbatim: "\(String(localized: "다음")) · \(next.title) \(TodayAgendaFormat.shortTime(next.start))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("남은 일정 \(state.remainingCount)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let focus = state.focus {
                    Button(intent: ToggleEventCompletionIntent(eventID: focus.id, eventDate: focus.start)) {
                        Label("완료", systemImage: "checkmark.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(hex: focus.colorHex))
                }
            }
            if isStale {
                Text("앱을 열어 최신 일정으로 갱신하세요")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 진행 중이면 종료까지, 아니면 시작까지 카운트다운. 시스템이 1초마다 갱신한다.
private struct TodayAgendaTimerText: View {
    let entry: TodayAgendaAttributes.Entry
    let isCurrent: Bool

    var body: some View {
        if isCurrent {
            Text(timerInterval: entry.start...entry.end, countsDown: true, showsHours: true)
        } else {
            Text(timerInterval: Date.distantPast...entry.start, countsDown: true, showsHours: true)
        }
    }
}

enum TodayAgendaFormat {
    static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func timeRange(_ start: Date, _ end: Date) -> String {
        "\(shortTime(start)) ~ \(shortTime(end))"
    }
}

// MARK: - Preview

#Preview("잠금화면", as: .content, using: TodayAgendaAttributes(dayKey: "2026-10-26")) {
    TodayAgendaLiveActivity()
} contentStates: {
    TodayAgendaAttributes.ContentState.sampleInProgress
    TodayAgendaAttributes.ContentState.sampleUpcoming
}

#Preview("DI expanded", as: .dynamicIsland(.expanded), using: TodayAgendaAttributes(dayKey: "2026-10-26")) {
    TodayAgendaLiveActivity()
} contentStates: {
    TodayAgendaAttributes.ContentState.sampleInProgress
}

#Preview("DI compact", as: .dynamicIsland(.compact), using: TodayAgendaAttributes(dayKey: "2026-10-26")) {
    TodayAgendaLiveActivity()
} contentStates: {
    TodayAgendaAttributes.ContentState.sampleUpcoming
}

extension TodayAgendaAttributes.ContentState {
    static let sampleInProgress: TodayAgendaAttributes.ContentState = {
        let now = Date()
        return .init(
            current: .init(id: "1", title: "스탠드업 미팅", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(1200), colorHex: "#4A90E2"),
            next: .init(id: "2", title: "분기 리포트 작성", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), colorHex: "#FF6B9D"),
            remainingCount: 3, completedCount: 1, totalCount: 4
        )
    }()

    static let sampleUpcoming: TodayAgendaAttributes.ContentState = {
        let now = Date()
        return .init(
            current: nil,
            next: .init(id: "2", title: "런치 & 1:1", start: now.addingTimeInterval(2700), end: now.addingTimeInterval(6300), colorHex: "#50C878"),
            remainingCount: 1, completedCount: 3, totalCount: 4
        )
    }()
}
