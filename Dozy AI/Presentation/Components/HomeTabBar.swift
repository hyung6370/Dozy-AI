//
//  HomeTabBar.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/31/26.
//

import SwiftUI

// MARK: - HomeTab

enum HomeTab: CaseIterable {
    case today, weekly, monthly

    var title: String {
        switch self {
        case .today:   return "오늘"
        case .weekly:  return "주간"
        case .monthly: return "월간"
        }
    }
}

// MARK: - HomeTabBar

struct HomeTabBar: View {

    @Binding var selectedTab: HomeTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6))
        )
    }

    private func tabButton(_ tab: HomeTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(tabBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func tabBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color(UIColor.systemBackground) : Color.clear)
            .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 4, y: 2)
    }
}

// MARK: - MonthlySummary

struct MonthlySummary {
    let totalEvents: Int
    let totalCompletedTasks: Int
    let averageProductivityScore: Double
    let activeDays: Int

    var scorePercentage: Int { Int(averageProductivityScore * 100) }
}

// MARK: - WeeklyDayRow

struct WeeklyDayRow: View {
    let date: Date
    let events: [CalendarEvent]

    private var dayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E M/d"
        return f.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayString)
                    .font(.caption)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? .blue : .secondary)

                if isToday {
                    Text("오늘")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Spacer()

                Text("\(events.count)개")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if events.isEmpty {
                Text("일정 없음")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray4))
                    .padding(.leading, 4)
            } else {
                ForEach(events.prefix(3)) { event in
                    EventRow(event: event)
                }
                if events.count > 3 {
                    Text("외 \(events.count - 3)개")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? Color.blue.opacity(0.04) : Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - MonthlyStatCard

struct MonthlyStatCard: View {
    let icon: String
    let label: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.07))
        )
    }
}
