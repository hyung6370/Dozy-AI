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
    @State private var selection: MacSection? = .today

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selection) { section in
                Label(section.displayName, systemImage: section.iconName)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("Dozy")
        } detail: {
            Group {
                switch selection {
                case .today:
                    MacTodayView(container: container)
                case .calendar:
                    MacCalendarPlaceholderView()
                case .insights:
                    MacInsightsPlaceholderView()
                case .settings:
                    MacSettingsPlaceholderView()
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

private struct MacCalendarPlaceholderView: View {
    var body: some View {
        PlaceholderDetail(title: "캘린더", note: "M4.5 에서 캘린더 뷰 구현 예정")
    }
}

private struct MacInsightsPlaceholderView: View {
    var body: some View {
        PlaceholderDetail(title: "인사이트", note: "M4.8 에서 인사이트 뷰 구현 예정")
    }
}

private struct MacSettingsPlaceholderView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("설정")
                .font(.largeTitle).bold()

            if let email = authViewModel.currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("M4.8 에서 설정 섹션 확장 예정")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("로그아웃") {
                authViewModel.signOut()
            }
            .buttonStyle(.bordered)
            .padding(.top, 12)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("설정")
    }
}

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
