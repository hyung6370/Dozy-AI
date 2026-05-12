//
//  MainTabView.swift
//  Dozy AI
//
//  v2.0.0: 시스템 탭바를 숨기고 DozyMainTabBar 를 safeAreaInset 으로 올린다.
//  TabView 자체는 유지 → 탭별 NavigationStack/뷰 lifecycle 을 SwiftUI 가 무료로 보존.
//

import SwiftUI
import Combine
import Lottie

/// 가운데 액션 버튼으로 일정을 만들 때 createDozyEventUseCase 실행 + cancellable 보관.
/// MainTabView 는 struct 라 Set<AnyCancellable> 를 직접 들 수 없어 별도 owner 가 필요.
@MainActor
final class DozyEventCreator: ObservableObject {
    /// 저장 성공 시 잠깐 표시할 success Lottie 트리거.
    @Published var showSuccessAnimation = false
    private let createUseCase: CreateDozyEventUseCase
    private let onSaved: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(createUseCase: CreateDozyEventUseCase, onSaved: @escaping () -> Void) {
        self.createUseCase = createUseCase
        self.onSaved = onSaved
    }

    func save(_ event: DozyEvent) {
        createUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.onSaved()
                self?.showSuccessAnimation = true
            })
            .store(in: &cancellables)
    }
}

struct MainTabView: View {

    private let container: DependencyContainer
    @StateObject private var calendarViewModel: CalendarViewModel
    @StateObject private var sharedCalendarViewModel: SharedCalendarViewModel
    @StateObject private var eventCreator: DozyEventCreator
    @State private var selection: MainTab = .home
    @State private var showCreateEvent = false
    @EnvironmentObject private var authViewModel: AuthViewModel

    @AppStorage(DozyBackgroundTheme.storageKey)
    private var backgroundThemeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var backgroundTheme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    init(container: DependencyContainer) {
        self.container = container
        let calendarVM = CalendarViewModel(container: container)
        _calendarViewModel = StateObject(wrappedValue: calendarVM)
        _sharedCalendarViewModel = StateObject(wrappedValue: SharedCalendarViewModel(
            createUseCase: container.createSharedCalendarUseCase,
            joinUseCase: container.joinSharedCalendarUseCase,
            leaveUseCase: container.leaveSharedCalendarUseCase,
            regenerateUseCase: container.regenerateSharedCalendarInviteCodeUseCase,
            updateNicknameUseCase: container.updateSharedCalendarNicknameUseCase,
            service: container.sharedCalendarService
        ))
        _eventCreator = StateObject(wrappedValue: DozyEventCreator(
            createUseCase: container.createDozyEventUseCase,
            onSaved: { [weak calendarVM] in calendarVM?.refreshData() }
        ))
    }

    private var selectionBinding: Binding<Int> {
        Binding(
            get: { selection.rawValue },
            set: { newValue in
                if let tab = MainTab(rawValue: newValue) {
                    selection = tab
                }
            }
        )
    }

    /// 탭바 본체에 마지막 콘텐츠가 가려지지 않도록 각 탭 화면에 두 가지 보정을 같이 건다.
    /// 1) .contentMargins(.bottom, ..., for: .scrollContent): ScrollView/List/Form 의 contentInset 으로 전파
    /// 2) .padding(.bottom, ...): contentMargins 가 일부 컨테이너에서 전파 안 될 때를 위한 fallback
    private let scrollBottomMargin: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottom) {
            // 0) Themed shell background — system 은 grouped 색, ambient/blob 은 해당 view.
            //    카드는 자체 solid groupedRow + tint 로 시인성 보장되므로 themed bg 위에서도 잘 보임.
            DozyShellBackgroundView(theme: backgroundTheme)

            // 1) Tabs content — safeAreaInset 으로 탭바 자리만큼 transparent spacer.
            //    탭바 visual 자체는 별도 layer (아래쪽)로 분리한다.
            TabView(selection: selectionBinding) {
                HomeView(container: container, selectedTab: selectionBinding)
                    .tabContentInset(scrollBottomMargin)
                    .tag(MainTab.home.rawValue)
                    .toolbar(.hidden, for: .tabBar)

                CalendarView(container: container, viewModel: calendarViewModel)
                    .tabContentInset(scrollBottomMargin)
                    .tag(MainTab.calendar.rawValue)
                    .toolbar(.hidden, for: .tabBar)

                InsightDashboardView(container: container, selectedTab: selectionBinding)
                    .tabContentInset(scrollBottomMargin)
                    .tag(MainTab.insight.rawValue)
                    .toolbar(.hidden, for: .tabBar)

                SettingsView(container: container)
                    .tabContentInset(scrollBottomMargin)
                    .tag(MainTab.settings.rawValue)
                    .toolbar(.hidden, for: .tabBar)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: dozyTabBarVisualHeight)
            }

            // 2) Create-event 커스텀 시트 — DozyBottomSheet 컴포넌트.
            //    탭바보다 아래 layer 라서 시트가 슬라이드 업할 때 탭바 뒤에서 올라오는 효과.
            DozyBottomSheet(isPresented: $showCreateEvent, bottomInset: dozyTabBarVisualHeight) {
                EventEditView(
                    eventToEdit: nil,
                    selectedDate: Date(),
                    onSave: { saved in
                        // 데이터 저장만. dismiss 는 EventEditView 의 performDismiss → onCancel 이 단일 경로로 처리.
                        eventCreator.save(saved)
                    },
                    onCancel: {
                        dismissCreateEventSheet()
                    }
                )
            }

            // 3) DozyMainTabBar — modal 이 그 뒤에서 올라오게 한다.
            DozyMainTabBar(
                selection: $selection,
                onReselect: handleReselect,
                onCreateEvent: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                        showCreateEvent.toggle()
                    }
                }
            )
        }
        // Success Lottie — ZStack 외부 overlay 로 두어 layout 에 영향 없이 화면 위에만 표시.
        .overlay {
            if eventCreator.showSuccessAnimation {
                LottieView(name: "success", loopMode: .playOnce, animationSpeed: 1.8) {
                    eventCreator.showSuccessAnimation = false
                }
                .scaleEffect(0.22)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            calendarViewModel.loadInitialData()
        }
        .onChange(of: selection) { _, newTab in
            if newTab == .calendar { calendarViewModel.refreshData() }
        }
        .sheet(item: Binding(
            get: { authViewModel.pendingInviteCode.map { InviteCodeWrapper(code: $0) } },
            set: { if $0 == nil { authViewModel.pendingInviteCode = nil } }
        )) { wrapper in
            SharedCalendarJoinView(viewModel: sharedCalendarViewModel, initialCode: wrapper.code)
        }
    }

    /// DozyMainTabBar 가 화면 bottom 에서 차지하는 visual height.
    private var dozyTabBarVisualHeight: CGFloat { 84 }

    private func handleReselect(_ tab: MainTab) {
        // 후속 작업: NotificationCenter.default.post(name: .dozyTabReselected, object: tab)
        // 각 화면이 ScrollViewReader 로 구독하면 더블탭 → 스크롤 투 톱 동작.
    }

    /// 일정 생성 시트 닫기 — 키보드를 먼저 hide 한 뒤 시트 dismiss 를 같은 animation 흐름으로 묶음.
    /// 키보드 hide 가 safeAreaInsets 를 변경하면서 탭바 등 layout 이 들썩이는 걸 줄인다.
    private func dismissCreateEventSheet() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            showCreateEvent = false
        }
    }
}

private struct InviteCodeWrapper: Identifiable {
    let code: String
    var id: String { code }
}

private extension View {
    /// 탭 화면의 마지막 콘텐츠가 커스텀 탭바에 가려지지 않도록 + List/Form 의 시스템 배경을
    /// 숨겨 themed shell background 가 비치게 한다.
    func tabContentInset(_ amount: CGFloat) -> some View {
        self
            .contentMargins(.bottom, amount, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: amount)
            }
    }
}
