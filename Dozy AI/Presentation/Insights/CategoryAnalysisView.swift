//
//  CategoryAnalysisView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/11/26.
//

import SwiftUI
import SwiftData

struct CategoryAnalysisView: View {

    let events: [CalendarEvent]
    let dozyEvents: [DozyEvent]
    let period: InsightPeriod

    @Query(sort: \UserCategory.order) private var userCategories: [UserCategory]

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
            let p = h < 12 ? String(localized: "오전") : String(localized: "오후")
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
            .padding()
        }
        .navigationTitle("카테고리 분석")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie").font(.system(size: 52)).foregroundStyle(.secondary)
            Text("분석할 일정 데이터가 없어요")
                .font(.headline)
            Text("Dozy에 일정을 추가하면\n카테고리 분석을 시작할 수 있어요")
                .font(.subheadline).foregroundStyle(.secondary)
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

    private func statCell(value: String, label: LocalizedStringKey, small: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(small ? .subheadline : .title2)
                .fontWeight(.bold)
                .lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 시간 분배

    private var timeDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("시간 분배", systemImage: "clock.fill").font(.headline)

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
            .frame(height: 18)

            VStack(spacing: 8) {
                ForEach(catStats) { stat in
                    HStack(spacing: 8) {
                        Circle().fill(stat.color).frame(width: 10, height: 10)
                        Text("\(stat.emoji) \(stat.name)").font(.caption)
                        Spacer()
                        if hasTime && stat.totalMinutes > 0 {
                            Text(minuteLabel(stat.totalMinutes))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        let pct = hasTime
                            ? Int(Double(stat.totalMinutes) / Double(totalMinutes) * 100)
                            : Int(Double(stat.count) / Double(totalCount) * 100)
                        Text("\(pct)%").font(.caption).fontWeight(.medium).frame(width: 36, alignment: .trailing)
                    }
                }
            }

            if !hasTime {
                Text("종일 일정만 있어 건수 기준으로 표시됩니다")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 일정 건수

    private var countBarCard: some View {
        let maxCount = catStats.map { $0.count }.max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Label("일정 건수", systemImage: "calendar.badge.clock").font(.headline)

            ForEach(catStats) { stat in
                HStack(spacing: 10) {
                    Text("\(stat.emoji) \(stat.name)")
                        .font(.caption).frame(width: 100, alignment: .leading).lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stat.color)
                                .frame(width: geo.size.width * CGFloat(stat.count) / CGFloat(maxCount), height: 12)
                                .animation(.easeOut(duration: 0.6), value: stat.count)
                        }
                    }
                    .frame(height: 12)

                    Text("\(stat.count)건").font(.caption2).foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 완료율 (Dozy 일정 기준)

    private var completionRateCard: some View {
        let dozyStats = catStats.filter { $0.totalDozy > 0 }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("카테고리별 완료율", systemImage: "checkmark.circle.fill").font(.headline)
                Spacer()
                Text("Dozy 일정 기준").font(.caption2).foregroundStyle(.secondary)
            }

            ForEach(dozyStats) { stat in
                VStack(spacing: 4) {
                    HStack {
                        Text("\(stat.emoji) \(stat.name)").font(.caption)
                        Spacer()
                        Text("\(stat.completedDozy)/\(stat.totalDozy)건")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("\(Int(stat.completionRate * 100))%")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(completionColor(stat.completionRate))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(completionColor(stat.completionRate))
                                .frame(width: geo.size.width * stat.completionRate, height: 8)
                                .animation(.easeOut(duration: 0.6), value: stat.completionRate)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 선호 시간대

    private var peakHourCard: some View {
        let withHour = catStats.filter { $0.peakHour != nil }

        return VStack(alignment: .leading, spacing: 12) {
            Label("선호 시간대", systemImage: "sun.max.fill").font(.headline)

            ForEach(withHour) { stat in
                HStack(spacing: 12) {
                    Text("\(stat.emoji) \(stat.name)")
                        .font(.caption).frame(width: 100, alignment: .leading).lineLimit(1)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                    if let label = stat.peakHourLabel {
                        Text(label)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(stat.color.opacity(0.15))
                            .foregroundStyle(stat.color)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 요일 패턴

    private var weekdayPatternCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("요일별 패턴", systemImage: "calendar").font(.headline)

            ForEach(catStats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(stat.emoji) \(stat.name)").font(.caption).fontWeight(.medium)
                        Spacer()
                        if let wd = stat.peakWeekday {
                            Text("주로 \(weekdayLabels[wd == 1 ? 0 : wd - 1])요일")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }

                    let maxWD = stat.weekdayCounts.values.max() ?? 1
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { wd in
                            let count = stat.weekdayCounts[wd] ?? 0
                            let label = weekdayLabels[wd == 1 ? 0 : wd - 1]
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(count > 0 ? stat.color.opacity(0.3 + Double(count) / Double(maxWD) * 0.7) : Color(.systemGray6))
                                    .frame(height: 28)
                                Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 집중도

    private var focusScoreCard: some View {
        let score = focusScore
        let (label, color): (String, Color) = {
            if catStats.count == 1 { return ("완전 집중", .green) }
            switch score {
            case 0.6...: return ("집중형", .green)
            case 0.35..<0.6: return ("균형형", .blue)
            default: return ("분산형", .orange)
            }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Label("집중도 분석", systemImage: "scope").font(.headline)

            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 10).frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: min(score, 1))
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: score)
                    Text("\(Int(score * 100))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(label).font(.title3).fontWeight(.semibold).foregroundStyle(color)
                    Text(catStats.count == 1
                         ? "하나의 카테고리에 집중했어요"
                         : "\(catStats.count)개 카테고리에 걸쳐 활동했어요")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func minuteLabel(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 {
            return m > 0
                ? String(localized: "\(h)시간 \(m)분")
                : String(localized: "\(h)시간")
        }
        return String(localized: "\(m)분")
    }

    private func completionColor(_ rate: Double) -> Color {
        switch rate {
        case 0.8...: return .green
        case 0.5..<0.8: return .blue
        default: return .orange
        }
    }
}
