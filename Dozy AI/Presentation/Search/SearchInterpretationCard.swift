//
//  SearchInterpretationCard.swift
//  Dozy AI
//
//  자연어 질의 해석 카드 (#72). 해석된 조건을 칩으로 보여 주고(탭해서 지우기 — 오해석을 바로 고친다),
//  집계를 물었으면 수치를 크게 보여 준다. 수치는 SearchAggregator 가 낸 값 그대로.
//

import SwiftUI

struct SearchInterpretationCard: View {

    let interpretation: SearchInterpretation
    let isLoading: Bool
    let onRemovePeriod: () -> Void
    let onRemoveCategory: () -> Void

    private var intent: SearchQueryIntent { interpretation.intent }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chips

            VStack(alignment: .leading, spacing: 2) {
                // 요약 줄 — 왼쪽은 집계 제목 또는 일정 수, 오른쪽 끝은 누가 해석했는지 배지
                HStack(alignment: .center, spacing: 8) {
                    if intent.aggregation != .none {
                        Text(aggregateTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let events = interpretation.result?.events {
                        Text("일정 \(events.count)개")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    engineBadge
                }

                if intent.aggregation != .none {
                    aggregateBody
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 조건 칩

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let period = intent.period {
                    chip(
                        symbol: "calendar",
                        text: period.isDefault ? String(localized: "\(period.label) · 기본") : period.label,
                        removeLabel: "기간 조건 지우기",
                        onRemove: onRemovePeriod
                    )
                }
                if let category = intent.categoryHint {
                    chip(symbol: "tag", text: category, removeLabel: "카테고리 조건 지우기", onRemove: onRemoveCategory)
                }
                if let keyword = intent.keyword, keyword.lowercased() != intent.categoryHint?.lowercased() {
                    chip(symbol: "magnifyingglass", text: keyword, removeLabel: nil, onRemove: nil)
                }
            }
        }
    }

    private func chip(symbol: String, text: String, removeLabel: LocalizedStringKey?, onRemove: (() -> Void)?) -> some View {
        HStack(spacing: 4) {
            Image(symbol: symbol).font(.caption)
            Text(verbatim: text).font(.caption).fontWeight(.medium)
            if let onRemove, let removeLabel {
                Button(action: onRemove) {
                    Image(symbol: "xmark.circle.fill").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(removeLabel))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    // MARK: - 해석 엔진 배지

    /// Apple Intelligence 는 강조색, 규칙 해석(날짜 인식)은 중립색 — 어떤 경로로 해석됐는지 한눈에.
    private var engineBadge: some View {
        let isOnDevice = intent.source == .onDevice
        let tint: Color = isOnDevice ? .accentColor : .secondary
        return HStack(spacing: 4) {
            Image(symbol: isOnDevice ? "sparkles" : "calendar")
                .font(.caption2.weight(.semibold))
            Text(verbatim: intent.source.label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("해석: \(intent.source.label)"))
    }

    // MARK: - 집계

    @ViewBuilder
    private var aggregateBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let aggregate = interpretation.result?.aggregate {
                Text(value(of: aggregate))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                if let caption = caption(of: aggregate) {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if isLoading {
                ProgressView()
                    .padding(.vertical, 6)
            }
        }
    }

    private var aggregateTitle: LocalizedStringKey {
        switch intent.aggregation {
        case .count: return "일정 횟수"
        case .totalHours: return "총 시간"
        case .completionRate: return "완료율"
        case .none: return ""
        }
    }

    private func value(of aggregate: SearchAggregate) -> String {
        switch aggregate.aggregation {
        case .count, .none:
            return String(localized: "\(aggregate.eventCount)번")
        case .totalHours:
            return Self.duration(minutes: aggregate.totalMinutes)
        case .completionRate:
            let percent = Int(((aggregate.completionRate ?? 0) * 100).rounded())
            return String(localized: "\(percent)%")
        }
    }

    private func caption(of aggregate: SearchAggregate) -> String? {
        switch aggregate.aggregation {
        case .totalHours:
            var parts = [String(localized: "일정 \(aggregate.eventCount)개")]
            if aggregate.allDayCount > 0 {
                parts.append(String(localized: "종일 일정 \(aggregate.allDayCount)개 제외"))
            }
            return parts.joined(separator: " · ")
        case .completionRate:
            return String(localized: "\(aggregate.eventCount)개 중 \(aggregate.completedCount)개 완료")
        case .count, .none:
            return nil
        }
    }

    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return String(localized: "\(h)시간 \(m)분") }
        if h > 0 { return String(localized: "\(h)시간") }
        return String(localized: "\(m)분")
    }
}
