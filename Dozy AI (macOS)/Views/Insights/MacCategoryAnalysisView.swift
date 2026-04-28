//
//  MacCategoryAnalysisView.swift
//  Dozy AI (macOS)
//
//  iOS CategoryAnalysisView 의 macOS 포팅 — 같은 카테고리별 통계를 보여주되
//  Color(.systemGray*) → Color(nsColor: .controlBackgroundColor) / .gray.opacity 로,
//  navigationBarTitleDisplayMode 같은 iOS 전용 modifier 는 제거.
//
//  Phase M5.2.a — 인사이트 대시보드의 "카테고리 분석" 카드 탭 시 진입.
//

import SwiftUI
import SwiftData

struct MacCategoryAnalysisView: View {

    let events: [CalendarEvent]
    let dozyEvents: [DozyEvent]
    let period: MacInsightPeriod

    @Query(sort: \UserCategory.order) private var userCategories: [UserCategory]
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local Model

    private struct CatStat: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        let colorHex: String
        let count: Int
        let totalMinutes: Int
        let completedDozy: Int
        let totalDozy: Int
        let peakHour: Int?
        let weekdayCounts: [Int: Int]

        var color: Color { Color(hex: colorHex) ?? .gray }
        var completionRate: Double {
            totalDozy > 0 ? Double(completedDozy) / Double(totalDozy) : 0
        }
        var peakWeekday: Int? {
            weekdayCounts.max(by: { $0.value < $1.value })?.key
        }
        var peakHourLabel: String? {
            guard let h = peakHour else { return nil }
            let p = h < 12 ? "오전" : "오후"
            let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            return "\(p) \(display)시"
        }
    }

    // MARK: - Computed Stats

    private func infoFor(_ name: String) -> (emoji: String, colorHex: String) {
        if let cat = userCategories.first(where: { $0.name == name }) {
            return (cat.emoji, cat.colorHex)
        }
        return ("📌", "#8E8E93")
    }

    private var catStats: [CatStat] {
        var timeMap: [String: (count: Int, minutes: Int, hours: [Int: Int], weekdays: [Int: Int])] = [:]
        var dozyMap: [String: (completed: Int, total: Int)] = [:]

        for event in events {
            let name = event.category
            var e = timeMap[name] ?? (count: 0, minutes: 0, hours: [:], weekdays: [:])
            e.count += 1
            e.minutes += event.isAllDay ? 0 : event.durationMinutes
            if !event.isAllDay {
                let h = Calendar.current.component(.hour, from: event.startDate)
                e.hours[h, default: 0] += 1
            }
            let wd = Calendar.current.component(.weekday, from: event.startDate)
            e.weekdays[wd, default: 0] += 1
            timeMap[name] = e
        }

        for dozy in dozyEvents {
            var d = dozyMap[dozy.category] ?? (completed: 0, total: 0)
            d.total += 1
            if dozy.isCompleted { d.completed += 1 }
            dozyMap[dozy.category] = d
        }

        return timeMap.map { name, data in
            let info = infoFor(name)
            let dozy = dozyMap[name] ?? (completed: 0, total: 0)
            let peakHour = data.hours.max(by: { $0.value < $1.value })?.key
            return CatStat(
                name: name, emoji: info.emoji, colorHex: info.colorHex,
                count: data.count, totalMinutes: data.minutes,
                completedDozy: dozy.completed, totalDozy: dozy.total,
                peakHour: peakHour, weekdayCounts: data.weekdays
            )
        }
        .sorted { $0.totalMinutes != $1.totalMinutes ? $0.totalMinutes > $1.totalMinutes : $0.count > $1.count }
    }

    private var totalMinutes: Int { catStats.reduce(0) { $0 + $1.totalMinutes } }
    private var totalCount: Int { catStats.reduce(0) { $0 + $1.count } }
    private var hasTime: Bool { totalMinutes > 0 }

    private var focusScore: Double {
        guard totalCount > 0 else { return 0 }
        return catStats.reduce(0.0) { $0 + pow(Double($1.count) / Double(totalCount), 2) }
    }

    private let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if catStats.isEmpty {
                    emptyState
                } else {
                    overviewCard
                    timeDistributionCard
                    countBarCard
                    if catStats.contains(where: { $0.totalDozy > 0 }) {
                        completionRateCard
                    }
                    if catStats.contains(where: { $0.peakHour != nil }) {
                        peakHourCard
                    }
                    weekdayPatternCard
                    focusScoreCard
                }
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("카테고리 분석")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("닫기") { dismiss() }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("분석할 일정 데이터가 없어요")
                .font(.headline)
            Text("Dozy에 일정을 추가하면\n카테고리 분석을 시작할 수 있어요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }

    // MARK: - 개요

    private var overviewCard: some View {
        let stats = catStats
        let topByTime = stats.first
        let topByCount = stats.max(by: { $0.count < $1.count })

        return HStack(spacing: 0) {
            statCell(value: "\(stats.count)개", label: "카테고리")
            Divider().frame(height: 40)
            if let top = topByTime {
                statCell(value: "\(top.emoji) \(top.name)", label: "가장 긴 시간", small: true)
            }
            Divider().frame(height: 40)
            if let top = topByCount {
                statCell(value: "\(top.emoji) \(top.name)", label: "가장 많은 건수", small: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(value: String, label: String, small: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(small ? .body : .title)
                .fontWeight(.bold)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 시간 분배

    private var timeDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("시간 분배", systemImage: "clock.fill").font(.title3)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(catStats) { stat in
                        let ratio = hasTime ? Double(stat.totalMinutes) / Double(totalMinutes)
                                            : Double(stat.count) / Double(totalCount)
                        let w = geo.size.width * ratio
                        if w > 2 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stat.color)
                                .frame(width: w - 2)
                        }
                    }
                }
            }
            .frame(height: 20)

            VStack(spacing: 10) {
                ForEach(catStats) { stat in
                    HStack(spacing: 10) {
                        Circle().fill(stat.color).frame(width: 12, height: 12)
                        Text("\(stat.emoji) \(stat.name)").font(.subheadline)
                        Spacer()
                        if hasTime && stat.totalMinutes > 0 {
                            Text(minuteLabel(stat.totalMinutes))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        let pct = hasTime
                            ? Int(Double(stat.totalMinutes) / Double(totalMinutes) * 100)
                            : Int(Double(stat.count) / Double(totalCount) * 100)
                        Text("\(pct)%")
                            .font(.subheadline).fontWeight(.medium)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            if !hasTime {
                Text("종일 일정만 있어 건수 기준으로 표시됩니다")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 일정 건수

    private var countBarCard: some View {
        let maxCount = catStats.map { $0.count }.max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            Label("일정 건수", systemImage: "calendar.badge.clock").font(.title3)

            ForEach(catStats) { stat in
                HStack(spacing: 12) {
                    Text("\(stat.emoji) \(stat.name)")
                        .font(.subheadline)
                        .frame(width: 130, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.18))
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stat.color)
                                .frame(width: geo.size.width * CGFloat(stat.count) / CGFloat(maxCount), height: 14)
                                .animation(.easeOut(duration: 0.6), value: stat.count)
                        }
                    }
                    .frame(height: 14)

                    Text("\(stat.count)건")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 완료율 (Dozy 일정 기준)

    private var completionRateCard: some View {
        let dozyStats = catStats.filter { $0.totalDozy > 0 }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("카테고리별 완료율", systemImage: "checkmark.circle.fill").font(.title3)
                Spacer()
                Text("Dozy 일정 기준")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ForEach(dozyStats) { stat in
                VStack(spacing: 6) {
                    HStack {
                        Text("\(stat.emoji) \(stat.name)").font(.subheadline)
                        Spacer()
                        Text("\(stat.completedDozy)/\(stat.totalDozy)건")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(stat.completionRate * 100))%")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(completionColor(stat.completionRate))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.18))
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(completionColor(stat.completionRate))
                                .frame(width: geo.size.width * stat.completionRate, height: 10)
                                .animation(.easeOut(duration: 0.6), value: stat.completionRate)
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 선호 시간대

    private var peakHourCard: some View {
        let withHour = catStats.filter { $0.peakHour != nil }

        return VStack(alignment: .leading, spacing: 14) {
            Label("선호 시간대", systemImage: "sun.max.fill").font(.title3)

            ForEach(withHour) { stat in
                HStack(spacing: 14) {
                    Text("\(stat.emoji) \(stat.name)")
                        .font(.subheadline)
                        .frame(width: 130, alignment: .leading)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption).foregroundStyle(.tertiary)
                    if let label = stat.peakHourLabel {
                        Text(label)
                            .font(.subheadline).fontWeight(.medium)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(stat.color.opacity(0.15))
                            .foregroundStyle(stat.color)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 요일 패턴

    private var weekdayPatternCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("요일별 패턴", systemImage: "calendar").font(.title3)

            ForEach(catStats) { stat in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(stat.emoji) \(stat.name)")
                            .font(.subheadline).fontWeight(.medium)
                        Spacer()
                        if let wd = stat.peakWeekday {
                            Text("주로 \(weekdayLabels[wd == 1 ? 0 : wd - 1])요일")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    let maxWD = stat.weekdayCounts.values.max() ?? 1
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { wd in
                            let count = stat.weekdayCounts[wd] ?? 0
                            let label = weekdayLabels[wd == 1 ? 0 : wd - 1]
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(count > 0
                                          ? stat.color.opacity(0.3 + Double(count) / Double(maxWD) * 0.7)
                                          : Color.gray.opacity(0.12))
                                    .frame(height: 36)
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 집중도

    private var focusScoreCard: some View {
        let score = focusScore
        let (label, color): (String, Color) = {
            if catStats.count == 1 { return ("완전 집중", .green) }
            switch score {
            case 0.6...:    return ("집중형", .green)
            case 0.35..<0.6: return ("균형형", .blue)
            default:        return ("분산형", .orange)
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            Label("집중도 분석", systemImage: "scope").font(.title3)

            HStack(spacing: 24) {
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.18), lineWidth: 12).frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0, to: min(score, 1))
                        .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: score)
                    Text("\(Int(score * 100))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(label)
                        .font(.title2).fontWeight(.semibold)
                        .foregroundStyle(color)
                    Text(catStats.count == 1
                         ? "하나의 카테고리에 집중했어요"
                         : "\(catStats.count)개 카테고리에 걸쳐 활동했어요")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func minuteLabel(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 { return m > 0 ? "\(h)시간 \(m)분" : "\(h)시간" }
        return "\(m)분"
    }

    private func completionColor(_ rate: Double) -> Color {
        switch rate {
        case 0.8...:     return .green
        case 0.5..<0.8:  return .blue
        default:         return .orange
        }
    }
}
