//
//  MacMainShellView.swift
//  Dozy AI (macOS)
//
//  M4.3 — NavigationSplitView 기반 메인 쉘. 현재는 섹션별 플레이스홀더만 포함하고
//  M4.4 이후 각 섹션의 실제 콘텐츠가 차례대로 채워진다.
//

import SwiftUI
import Lottie

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

    /// iOS 와 공유하는 커스텀 에셋 이름. light/dark × default/selected 조합.
    func assetName(isSelected: Bool, colorScheme: ColorScheme) -> String {
        let prefix = colorScheme == .dark ? "Dark" : "Light"
        let stem: String
        switch self {
        case .today:    stem = "House"
        case .calendar: stem = "Calendar"
        case .insights: stem = "Insight"
        case .settings: stem = "Setting"
        }
        let suffix = isSelected ? "-selected" : ""
        return "\(prefix)-\(stem)\(suffix)"
    }
}

// MARK: - Main Shell

struct MacMainShellView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var coordinator: MacAppCoordinator
    @Environment(\.colorScheme) private var colorScheme

    /// List 의 selection 바인딩은 view update 중 published 프로퍼티에 직접 쓰면
    /// "Publishing changes from within view updates" 경고가 떠서, 로컬 @State 에
    /// 두고 onChange 로 coordinator 와 양방향 동기화한다.
    @State private var selection: MacSection? = .today

    @AppStorage("macBackgroundTheme")
    private var backgroundThemeRaw: String = MacBackgroundTheme.defaultTheme.rawValue

    private var backgroundTheme: MacBackgroundTheme {
        MacBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selection) { section in
                let isSelected = selection == section
                Label {
                    Text(section.displayName)
                } icon: {
                    Image(section.assetName(isSelected: isSelected, colorScheme: colorScheme))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                .tag(section)
            }
            .listStyle(.sidebar)
            .modifier(ThemedContainerBackground(theme: backgroundTheme))
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("Dozy")
            .onAppear { selection = coordinator.selectedSection }
            .onChange(of: selection) { _, newValue in
                if coordinator.selectedSection != newValue {
                    coordinator.selectedSection = newValue
                }
            }
            .onChange(of: coordinator.selectedSection) { _, newValue in
                if selection != newValue {
                    selection = newValue
                }
            }
        } detail: {
            // ZStack 으로 detail child 와 Lottie 를 sibling 으로 배치 — switch 의 case
            // 가 갈려도 Lottie 는 ZStack 의 두 번째 자식 자리에서 identity 가 유지되어
            // NSViewRepresentable 가 tear down 되지 않는다. .overlay 를 Group 에 직접
            // 걸면 case 변경 시 Lottie NSView 가 재생성돼 처음부터 다시 재생되는 버그.
            ZStack {
                Group {
                    switch coordinator.selectedSection {
                    case .today:
                        if let vm = coordinator.homeViewModel {
                            MacTodayView(viewModel: vm)
                        }
                    case .calendar:
                        if let vm = coordinator.calendarViewModel {
                            MacCalendarView(viewModel: vm)
                        }
                    case .insights:
                        MacInsightDashboardView(container: container)
                    case .settings:
                        MacSettingsView()
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
                .modifier(ThemedContainerBackground(theme: backgroundTheme))

                // 로그인 직후 축하 애니메이션 — detail 영역 정중앙. 윈도우 짧은 변의 70%.
                if authViewModel.showCongratulationAnimation {
                    GeometryReader { proxy in
                        let side = min(proxy.size.width, proxy.size.height) * 0.7
                        MacLottieView(name: "congratulation", loopMode: .playOnce) {
                            authViewModel.showCongratulationAnimation = false
                        }
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }
}

/// 선택된 테마에 맞춰 컨테이너 배경을 입히는 modifier. `.system` 인 경우 macOS
/// 기본 머티리얼/배경을 그대로 살리기 위해 `.scrollContentBackground` 도 건드리지 않는다.
private struct ThemedContainerBackground: ViewModifier {
    let theme: MacBackgroundTheme

    func body(content: Content) -> some View {
        if theme == .system {
            content
        } else {
            content
                .scrollContentBackground(.hidden)
                .background {
                    MacShellBackgroundView(theme: theme)
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
