//
//  MacMainShellView.swift
//  Dozy AI (macOS)
//
//  M4.3 — NavigationSplitView 기반 메인 쉘. 현재는 섹션별 플레이스홀더만 포함하고
//  M4.4 이후 각 섹션의 실제 콘텐츠가 차례대로 채워진다.
//

import SwiftUI

// MARK: - Section

enum MacSection: String, CaseIterable, Hashable, Identifiable {
    case today
    case calendar
    case insights
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "오늘"
        case .calendar: return "캘린더"
        case .insights: return "인사이트"
        case .settings: return "설정"
        }
    }

    var iconName: String {
        switch self {
        case .today: return "sun.max.fill"
        case .calendar: return "calendar"
        case .insights: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main Shell

struct MacMainShellView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var coordinator: MacAppCoordinator

    var body: some View {
        NavigationSplitView {
            List(
                MacSection.allCases,
                selection: Binding(
                    get: { coordinator.selectedSection },
                    set: { coordinator.selectedSection = $0 }
                )
            ) { section in
                Label(section.displayName, systemImage: section.iconName)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("Dozy")
        } detail: {
            Group {
                switch coordinator.selectedSection {
                case .today:     MacTodayView(container: container)
                case .calendar:  MacCalendarView(container: container)
                case .insights:  MacInsightDashboardView(container: container)
                case .settings:  MacSettingsView()
                case nil:
                    VStack(spacing: 8) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("섹션을 선택하세요")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Placeholder Detail Views

private struct PlaceholderDetail: View {
    let title: String
    let note: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle).bold()
            Text(note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
    }
}
