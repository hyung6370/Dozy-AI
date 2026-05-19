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
import OSLog

/// 가운데 액션 버튼으로 일정을 만들 때 createDozyEventUseCase 실행 + cancellable 보관.
/// MainTabView 는 struct 라 Set<AnyCancellable> 를 직접 들 수 없어 별도 owner 가 필요.
///
/// `onSaved` 는 init 이 아니라 onAppear 단계에서 외부가 set 한다. 이 패턴이 필요한 이유:
/// MainTabView.init 이 SwiftUI 의 body re-eval 마다 호출돼도 @StateObject autoclosure 가
/// VM 들을 최초 1회만 생성하도록 하려면, init 단계에서 cross-VM 강한/약한 캡처를 안 만들어야
/// 한다. 이전 패턴은 매 init 마다 transient CalendarViewModel 을 생성해 NotificationCenter
/// 구독이 중복 발화되던 폭주 원인이었음 (#53).
@MainActor
final class DozyEventCreator: ObservableObject {
    /// 저장 성공 시 잠깐 표시할 success Lottie 트리거.
    @Published var showSuccessAnimation = false
    private let createUseCase: CreateDozyEventUseCase
    /// onAppear 에서 wire 됨. nil 이면 save 후 콜백 없음 (시각 피드백만).
    var onSaved: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init(createUseCase: CreateDozyEventUseCase) {
        self.createUseCase = createUseCase
    }

    func save(_ event: DozyEvent) {
        createUseCase.execute(event)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.onSaved?()
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
    /// HomeViewModel 을 여기서 소유 — 캘린더 탭 진입 사용자에게도 scenePhase active 시
    /// loadTodayData 가 돌아야 위젯 TodayEventCache 가 Apple/Google 머지본으로 갱신됨.
    @StateObject private var homeViewModel: HomeViewModel
    @State private var selection: MainTab = .home
    @State private var showCreateEvent = false
    /// 캘린더 탭에서 아래로 스크롤하면 true → DozyMainTabBar 를 화면 밖으로 슬라이드.
    /// 다른 탭으로 이동하거나 다시 캘린더에 진입하면 false 로 리셋.
    @State private var calendarTabBarHidden = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
    private var backgroundThemeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var backgroundTheme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    init(container: DependencyContainer) {
        self.container = container
        // ⚠️ autoclosure 형식 — `_calendarViewModel = StateObject(wrappedValue: CalendarViewModel(...))`
        // 는 SwiftUI 가 처음 view 를 만들 때 한 번만 평가된다. 이전엔 init 안에서 `let vm = CalendarViewModel(...)`
        // 으로 eager 하게 만든 뒤 StateObject 에 넘겼는데, 그러면 init 이 호출될 때마다 transient
        // VM 이 새로 생성되고 그 convenience init 이 NotificationCenter 구독을 등록 → 정리 타이밍이
        // 어긋나며 같은 알림이 2회 이상 수신되던 폭주 원인이었음 (#53).
        _calendarViewModel = StateObject(wrappedValue: CalendarViewModel(container: container))
        _sharedCalendarViewModel = StateObject(wrappedValue: SharedCalendarViewModel(
            createUseCase: container.createSharedCalendarUseCase,
            joinUseCase: container.joinSharedCalendarUseCase,
            leaveUseCase: container.leaveSharedCalendarUseCase,
            regenerateUseCase: container.regenerateSharedCalendarInviteCodeUseCase,
            updateNicknameUseCase: container.updateSharedCalendarNicknameUseCase,
            service: container.sharedCalendarService
        ))
        _eventCreator = StateObject(wrappedValue: DozyEventCreator(
            createUseCase: container.createDozyEventUseCase
        ))
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(container: container))
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
                HomeView(container: container, selectedTab: selectionBinding, viewModel: homeViewModel)
                    .tabContentInset(scrollBottomMargin)
                    .tag(MainTab.home.rawValue)
                    .toolbar(.hidden, for: .tabBar)

                CalendarView(
                    container: container,
                    viewModel: calendarViewModel,
                    tabBarHidden: $calendarTabBarHidden
                )
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
            //    캘린더 탭에서 아래로 스크롤 시 화면 밖으로 슬라이드.
            DozyMainTabBar(
                selection: $selection,
                onReselect: handleReselect,
                onCreateEvent: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                        showCreateEvent.toggle()
                    }
                }
            )
            .offset(y: shouldHideTabBar ? dozyTabBarHideOffset : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.9), value: shouldHideTabBar)
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
            Logger.nav.info("[앱] 🧭 MainTabView 진입 (현재 탭: \(selection.title))")
            // DozyEventCreator 의 onSaved 를 init 이 아니라 여기서 wire — init 에서 cross-VM 캡처를
            // 피해 @StateObject autoclosure 가 VM 들을 최초 1회만 생성하도록 보장 (#53).
            // onAppear 가 여러 번 발화돼도 같은 클로저를 재할당하는 것이라 부작용 없음.
            eventCreator.onSaved = { [weak calendarViewModel] in
                calendarViewModel?.refreshData(source: "DozyEventCreator.onSaved")
            }
            calendarViewModel.loadInitialData(source: "MainTabView.onAppear")
            // 콜드 스타트에서 어떤 탭으로 진입하든 위젯 TodayEventCache 가 Apple/Google
            // 머지본으로 채워지도록 home VM 의 fetch+미러 파이프라인을 한 번 트리거.
            // HomeViewModel.loadTodayData 자체에 throttle 이 있어 burst 호출은 안전.
            homeViewModel.loadTodayData()
        }
        .onChange(of: selection) { old, newTab in
            Logger.nav.info("[탭 전환] 🧭 \(old.title) → \(newTab.title)")
            if newTab == .calendar { calendarViewModel.refreshData(source: "MainTabView.selection→calendar") }
            // 다른 탭에서 캘린더 진입 시 — 직전 세션의 hide 상태가 남아있으면 안 되니 리셋.
            if newTab != old { calendarTabBarHidden = false }
        }
        .onChange(of: scenePhase) { old, phase in
            Logger.nav.info("[앱 상태] 🌅 \(String(describing: old)) → \(String(describing: phase))")
            // 웜 포그라운드 — 캘린더 탭에 머물고 있어도 위젯 캐시가 최신 머지본으로 갱신되도록.
            if phase == .active { homeViewModel.loadTodayData() }
        }
        .onChange(of: showCreateEvent) { _, isOpen in
            Logger.nav.info("[시트: 일정 생성] 📋 \(isOpen ? "OPEN" : "CLOSE")")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyWidgetOpenAddEvent)) { _ in
            // 잠금화면 위젯 accessoryCircular 의 widgetURL 탭으로 들어옴 →
            // 홈 탭으로 이동 후 일정 생성 바텀시트 오픈.
            selection = .home
            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                showCreateEvent = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyWidgetOpenCalendar)) { _ in
            // systemLarge 위젯의 미니 캘린더 / 하단 일정 리스트 탭 → 캘린더 탭으로 이동.
            selection = .calendar
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyWidgetOpenEventDetail)) { _ in
            // accessoryRectangular 탭 → 홈 탭으로 먼저 이동. 상세 시트 띄우기는 HomeView 가 처리.
            selection = .home
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

    /// 탭바를 화면 밖으로 밀어내는 offset — visual height + 홈 인디케이터 safe area 여유 포함.
    private var dozyTabBarHideOffset: CGFloat { dozyTabBarVisualHeight + 60 }

    /// 캘린더 탭에서 스크롤로 hide 신호가 켜졌을 때만 슬라이드. 다른 탭은 항상 표시.
    private var shouldHideTabBar: Bool {
        selection == .calendar && calendarTabBarHidden
    }

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
