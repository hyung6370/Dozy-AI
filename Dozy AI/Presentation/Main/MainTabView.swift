//
//  MainTabView.swift
//  Dozy AI
//
//  시스템 탭바를 숨기고 플로팅 Liquid Glass 탭바(DozyMainTabBar)를 overlay 로 띄운다.
//  TabView 자체는 유지 → 탭별 NavigationStack/뷰 lifecycle 을 SwiftUI 가 무료로 보존.
//  탭 루트 스크롤(drivesTabBarChrome)이 "위로 쓸기" 를 보고하면 DozyTabBarChrome 이 바를 축소한다.
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

    func save(_ event: DozyEvent, method: EventInputMethod = .manual) {
        createUseCase.execute(event, method: method)
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
    /// 생성 시트를 위젯 "+ 새 일정"이 열었는지 — 수동 입력이면 `event_created(method: widget)` 로 구분 (#90).
    @State private var createEventFromWidget = false
    /// 하단 탭바 축소 상태 + 재터치 '맨 위로' 틱. 탭 루트 스크롤뷰(drivesTabBarChrome)가 구동한다.
    @State private var chrome = DozyTabBarChrome()
    /// 키보드가 올라와 있는 동안 true — 탭바를 내려 둔다(키보드 위에 바가 겹쳐 뜨지 않게).
    @State private var keyboardVisible = false
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

    /// 떠 있는 탭바가 마지막 콘텐츠를 덮지 않도록 각 탭 스크롤 콘텐츠에 주는 하단 여백.
    /// 바 뒤로 콘텐츠가 비쳐야 하므로(글라스) safeAreaInset 이 아니라 contentMargins 만 쓴다.
    private let scrollBottomMargin: CGFloat = DozyTabBarMetrics.scrollClearance

    var body: some View {
        ZStack(alignment: .bottom) {
            // 0) Themed shell background — system 은 grouped 색, ambient/blob 은 해당 view.
            //    카드는 자체 solid groupedRow + tint 로 시인성 보장되므로 themed bg 위에서도 잘 보임.
            DozyShellBackgroundView(theme: backgroundTheme)

            // 1) Tabs content — 떠 있는 글라스 바 뒤로 콘텐츠가 지나가도록 safeAreaInset 은 두지 않고
            //    각 탭의 스크롤 콘텐츠에 하단 여백(contentMargins)만 준다.
            TabView(selection: selectionBinding) {
                HomeView(container: container, selectedTab: selectionBinding, viewModel: homeViewModel)
                    .tabContentInset(scrollBottomMargin)
                    .environment(\.dozyTab, .home)
                    .tag(MainTab.home.rawValue)
                    .toolbar(.hidden, for: .tabBar)

                CalendarView(container: container, viewModel: calendarViewModel)
                    .tabContentInset(scrollBottomMargin)
                    .environment(\.dozyTab, .calendar)
                    .tag(MainTab.calendar.rawValue)
                    .toolbar(.hidden, for: .tabBar)

                InsightDashboardView(container: container, selectedTab: selectionBinding)
                    .tabContentInset(scrollBottomMargin)
                    .environment(\.dozyTab, .insight)
                    .tag(MainTab.insight.rawValue)
                    .toolbar(.hidden, for: .tabBar)

                SettingsView(container: container)
                    .tabContentInset(scrollBottomMargin)
                    .environment(\.dozyTab, .settings)
                    .tag(MainTab.settings.rawValue)
                    .toolbar(.hidden, for: .tabBar)
            }

            // 2) Create-event 커스텀 시트 — DozyBottomSheet 컴포넌트.
            //    탭바보다 아래 layer 라서 시트가 슬라이드 업할 때 탭바 뒤에서 올라오는 효과.
            DozyBottomSheet(isPresented: $showCreateEvent, bottomInset: 0) {
                EventEditView(
                    eventToEdit: nil,
                    selectedDate: createEventDefaultDate,
                    sharedCalendars: calendarViewModel.sharedCalendarsForEditing(),
                    parseUseCase: container.parseNaturalLanguageEventUseCase,   // 자연어 한 줄 → 폼 채우기
                    speechService: container.speechService,                       // 빠른 입력 카드의 마이크
                    onSaveWithMethod: { saved, method in
                        // 데이터 저장만. dismiss 는 EventEditView 의 performDismiss → onCancel 이 단일 경로로 처리.
                        eventCreator.save(saved, method: method == .manual && createEventFromWidget ? .widget : method)
                        createEventFromWidget = false
                    },
                    onCancel: {
                        dismissCreateEventSheet()
                    }
                )
            }

            // 3) 플로팅 글라스 탭바 — modal 이 그 뒤에서 올라오게 한다.
            //    탭 루트를 위로 쓸면 축소(라벨 접힘), 아래로 쓸거나 탭을 바꾸면 복원.
            //    하위 화면(push)·일정 생성 시트에서는 아래로 내려가며 사라진다.
            ZStack(alignment: .bottom) {
                if showsTabBar {
                    DozyMainTabBar(
                        selection: $selection,
                        isCompact: chrome.isCompact,
                        onReselect: handleReselect,
                        onCreateEvent: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                                showCreateEvent.toggle()
                            }
                        }
                    )
                    .padding(.bottom, DozyTabBarMetrics.bottomMargin)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: chrome.isCompact)
            .animation(.spring(response: 0.42, dampingFraction: 0.85), value: showsTabBar)
        }
        .environment(chrome)
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
            chrome.reset()   // 탭 전환은 항상 펼친 상태로
        }
        .onChange(of: scenePhase) { old, phase in
            Logger.nav.info("[앱 상태] 🌅 \(String(describing: old)) → \(String(describing: phase))")
            // 웜 포그라운드 — 캘린더 탭에 머물고 있어도 위젯 캐시가 최신 머지본으로 갱신되도록.
            if phase == .active { homeViewModel.loadTodayData() }
        }
        .onChange(of: showCreateEvent) { _, isOpen in
            Logger.nav.info("[시트: 일정 생성] 📋 \(isOpen ? "OPEN" : "CLOSE")")
        }
        .onChange(of: homeViewModel.showEveningCheck) { _, isShown in
            // 저녁 일정 체크 시트는 HomeView 에 붙어 있다 — 다른 탭에 있었다면 홈으로 옮겨서 띄운다.
            if isShown { selection = .home }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyWidgetOpenAddEvent)) { _ in
            // 잠금화면 위젯 accessoryCircular 의 widgetURL 탭으로 들어옴 →
            // 홈 탭으로 이동 후 일정 생성 바텀시트 오픈.
            selection = .home
            createEventFromWidget = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                showCreateEvent = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyRequestNewEvent)) { _ in
            // 캘린더 날짜 길게 누르기 → 생성. 탭은 그대로 두고 같은 생성 시트를 연다 (기본 날짜 = 캘린더 selectedDate).
            guard !showCreateEvent else { return }
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
        .onReceive(NotificationCenter.default.publisher(for: .dozyOpenVoiceInput)) { _ in
            // Siri 음성 메모 → 홈 탭으로 먼저 이동. 시트 띄우기는 HomeView 가 처리.
            selection = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .dozyOpenDailySummary)) { _ in
            // 저녁 요약 알림 탭 → 홈 탭으로 먼저 이동. 요약 시트는 HomeView 가 연다.
            selection = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .sheet(item: Binding(
            get: { authViewModel.pendingInviteCode.map { InviteCodeWrapper(code: $0) } },
            set: { if $0 == nil { authViewModel.pendingInviteCode = nil } }
        )) { wrapper in
            SharedCalendarJoinView(viewModel: sharedCalendarViewModel, initialCode: wrapper.code)
        }
    }

    /// 일정 생성 시트가 기본으로 쓸 날짜.
    /// 캘린더 탭이면 그리드에서 포커스된 날짜(selectedDate) 기준, 그 외 탭은 오늘.
    /// `content()` 가 시트 표시 시점에만 평가되므로(DozyBottomSheet) 항상 최신 포커스 날짜를 받는다.
    private var createEventDefaultDate: Date {
        selection == .calendar ? calendarViewModel.selectedDate : Date()
    }

    /// 탭바 노출 조건 — 현재 탭이 루트 화면이고(하위 push 아님), 그 탭의 커스텀 오버레이(hidesTabBar)가 없고,
    /// 일정 생성 시트가 닫혀 있고, 키보드가 내려가 있을 때.
    private var showsTabBar: Bool {
        chrome.showsBar(for: selection) && !showCreateEvent && !keyboardVisible
    }

    /// 이미 선택된 탭 재터치 → 그 탭 루트 스크롤뷰를 맨 위로(drivesTabBarChrome 이 처리).
    private func handleReselect(_ tab: MainTab) {
        chrome.reselect(tab)
    }

    /// 일정 생성 시트 닫기 — 키보드를 먼저 hide 한 뒤 시트 dismiss 를 같은 animation 흐름으로 묶음.
    /// 키보드 hide 가 safeAreaInsets 를 변경하면서 탭바 등 layout 이 들썩이는 걸 줄인다.
    private func dismissCreateEventSheet() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        createEventFromWidget = false
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
    /// 탭 화면의 마지막 콘텐츠가 떠 있는 탭바에 가려지지 않도록 스크롤 콘텐츠에만 하단 여백을 주고,
    /// List/Form 의 시스템 배경을 숨겨 themed shell background 가 비치게 한다.
    /// safeAreaInset 은 쓰지 않는다 — 글라스 바 뒤로 콘텐츠가 비쳐야 한다.
    func tabContentInset(_ amount: CGFloat) -> some View {
        self
            .contentMargins(.bottom, amount, for: .scrollContent)
            .scrollContentBackground(.hidden)
    }
}
