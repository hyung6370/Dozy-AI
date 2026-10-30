//
//  SettingsView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/6/26.
//

import SwiftUI
import SafariServices

struct SettingsView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase

    /// 설정 행 아이콘. 색은 한 가지로 통일하고, 강조할 행(AI 엔진)만 accent.
    private func settingIcon(_ symbol: String, accent: Bool = false) -> some View {
        Image(symbol: symbol)
            .font(.system(size: 16))
            .foregroundStyle(accent ? DozyColor.Brand.primary : DozyColor.Text.primary)
            .frame(width: 34)
    }
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showPasswordChange = false
    /// DragGesture 기반 커스텀 로그인 시트 (AuthSheetView) 표시 여부.
    @State private var showLoginSheet = false
    #if os(iOS)
    /// 저녁 요약 알림 설정 (UserDefaults 와 동기화).
    @State private var reminderSettings = SummaryReminderSettings.load()
    @State private var showReminderDeniedAlert = false
    /// 저녁 일정 체크 프롬프트 (18시 이후 앱을 열면 미완료 일정을 1회 물어봄). 기본 켜짐.
    @AppStorage(EveningCheckPrompt.enabledKey) private var eveningCheckEnabled = true
    @AppStorage(AnalyticsSettings.enabledKey) private var analyticsEnabled = true
    /// 잠금화면 · 다이나믹 아일랜드 "오늘 아젠다" Live Activity. 기본 켜짐 (UserDefaults 와 동기화).
    @State private var liveActivityEnabled = LiveActivitySettings.isEnabled()
    #endif
    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
    private var backgroundThemeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var backgroundTheme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    private let container: DependencyContainer
    /// 설정 "새 공유 일정 알림" (#95) — 기기 값이 기준, 서버 플래그는 토글 때 맞춘다.
    @State private var sharedPushEnabled = PushSettings.isSharedNotificationsEnabled()

    private var privacyPolicyURL: URL? {
        guard
            let str = Bundle.main.infoDictionary?["PRIVACY_POLICY_URL"] as? String,
            let url = URL(string: str)
        else { return nil }
        return url
    }
    
    init(container: DependencyContainer) {
        self.container = container
    }
    
    var body: some View {
        ZStack {
            settingsContent

            // DragGesture 커스텀 시트 — 시스템 .sheet 가 아니라 같은 뷰 계층의
            // 오버레이라서 SettingsView 의 alert 들이 시트 위에도 정상 표시된다.
            if showLoginSheet {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        guard !authViewModel.isLoading else { return }
                        withAnimation(.spring()) { showLoginSheet = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                AuthSheetView(isPresented: $showLoginSheet)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .hidesTabBar(showLoginSheet)   // 커스텀 로그인 시트가 떠 있는 동안 탭바 숨김
        // 로그인 성공 → 시트 닫기. 축하 Lottie 는 MainTabView 루트 overlay 에서 재생 (#139).
        .onChange(of: authViewModel.isLoggedIn) { _, loggedIn in
            if loggedIn {
                withAnimation(.spring()) { showLoginSheet = false }
            }
        }
    }

    private var settingsContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DozySpacing.xl) {
                    accountSection
                    appearanceSection
                    #if os(iOS)
                    summaryReminderSection
                    if authViewModel.isLoggedIn {
                        sharedPushSection
                    }
                    lockScreenSection
                    #endif
                    calendarSection
                    categorySection
                    infoSection
                    if authViewModel.currentUser?.provider == .email {
                        passwordChangeSection
                    }
                    dangerZoneSection
                }
                .padding(.vertical, DozySpacing.lg)
            }
            .drivesTabBarChrome()   // 위로 쓸기 → 탭바 축소 / 설정 탭 재터치 → 맨 위로
            .tracksTabRoot()        // 하위 화면 push 시 탭바 숨김
            // system 일 때는 grouped, ambient/blob 일 땐 themed bg — modifier 가 단일 layer 로 처리.
            .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .alert("로그아웃", isPresented: $showSignOutAlert) {
                Button("로그아웃", role: .destructive) { authViewModel.signOut() }
                Button("취소", role: .cancel) { }
            } message: {
                Text("정말로 로그아웃 하시겠습니까?")
            }
            .alert("오류", isPresented: Binding(
                get: { authViewModel.errorMessage != nil },
                set: { if !$0 { authViewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { authViewModel.errorMessage = nil }
            } message: {
                Text(authViewModel.errorMessage ?? "")
            }
            .alert("계정을 탈퇴하시겠습니까?", isPresented: $showDeleteAccountAlert) {
                Button("탈퇴", role: .destructive) {
                    authViewModel.deleteAccount()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("모든 일정, 기록, 카테고리가 영구적으로 삭제됩니다.")
            }
            .sheet(isPresented: $showPasswordChange) {
                PasswordChangeSheet()
                    .environmentObject(authViewModel)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    showSignOutAlert = false
                    showDeleteAccountAlert = false
                    authViewModel.errorMessage = nil
                }
            }
        }
    }
    
    // MARK: - 계정 섹션
    
    private var accountSection: some View {
        DozyListSection(
            header: "계정",
            footer: authViewModel.isLoggedIn
                ? "로그인 상태에서는 데이터가 서버에 백업됩니다."
                : "로그인하면 기기를 바꿔도 데이터를 유지할 수 있어요."
        ) {
            if authViewModel.isLoggedIn {
                loggedInRow
                    .padding(.horizontal, DozySpacing.md)
                    .padding(.vertical, DozySpacing.sm)
            } else {
                // 패딩을 버튼 label 안쪽에 두어 카드 가장자리까지 탭 영역에 포함.
                loggedOutRow
            }
        }
    }
    
    private var loggedInRow: some View {
        HStack(spacing: 14) {
            providerIcon(for: authViewModel.currentUser?.provider)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(authViewModel.currentUser?.displayName ?? String(localized: "사용자"))
                    .font(.subheadline).fontWeight(.medium)
                Text(authViewModel.currentUser?.email ?? "")
                    .font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("로그아웃") { showSignOutAlert = true }
                .font(.subheadline)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    /// 비로그인 상태의 CTA 행 — 탭하면 AuthSheetView 가 아래에서 올라온다.
    private var loggedOutRow: some View {
        Button {
            withAnimation(.spring()) { showLoginSheet = true }
        } label: {
            HStack(spacing: 14) {
                Image(symbol: "person.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundStyle(DozyColor.Text.primary)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("로그인 · 회원가입")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("데이터를 안전하게 백업하세요")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, DozySpacing.md)
            .padding(.vertical, DozySpacing.sm)
            // 텍스트/아이콘만이 아니라 카드 전체(빈 영역·가장자리 포함)가 탭 되도록.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func providerIcon(for provider: AuthProvider?) -> some View {
        switch provider {
        case .apple:
            Image(symbol: "apple.logo")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 34)
        case .google:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
        case .email:
            Image(symbol: "envelope.fill")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 34)
        case nil:
            Color.clear.frame(width: 34)
        }
    }
    
    // MARK: - 화면 (테마) 섹션

    private var appearanceSection: some View {
        DozyListSection(header: "화면") {
            NavigationLink {
                BackgroundThemePickerView()
            } label: {
                DozyListRow(title: "테마") {
                    settingIcon("paintpalette.fill")
                } trailing: {
                    HStack(spacing: DozySpacing.xs) {
                        DozyTrailingValue(text: backgroundTheme.displayName)
                        DozyChevron()
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 공유 캘린더 알림 섹션 (#95)

    #if os(iOS)
    private var sharedPushSection: some View {
        DozyListSection(
            header: "공유 캘린더 알림",
            footer: "파트너가 공유 캘린더에 일정을 추가하면 앱이 꺼져 있어도 알려드려요."
        ) {
            DozyListRow(title: "새 공유 일정 알림") {
                settingIcon("person.2.fill")
            } trailing: {
                Toggle("새 공유 일정 알림", isOn: Binding(
                    get: { sharedPushEnabled },
                    set: { enabled in
                        sharedPushEnabled = enabled
                        Task { await container.pushRegistrationUseCase.setSharedNotificationsEnabled(enabled) }
                    }
                ))
                .labelsHidden()
                .tint(DozyColor.Brand.primary)
            }
        }
    }
    #endif

    // MARK: - AI 요약 알림 섹션

    #if os(iOS)
    private var summaryReminderSection: some View {
        DozyListSection(
            header: "AI 요약 알림",
            footer: "정한 시각에 오늘 하루 요약을 알려드려요. 알림을 누르면 요약 화면이 바로 열립니다."
        ) {
            DozyListRow(title: "저녁 요약 알림") {
                settingIcon("bell.badge.fill")
            } trailing: {
                Toggle("저녁 요약 알림", isOn: $reminderSettings.isEnabled)
                    .labelsHidden()
                    .tint(DozyColor.Brand.primary)
            }

            if reminderSettings.isEnabled {
                DozyListRow(title: "알림 시각") {
                    settingIcon("clock.fill")
                } trailing: {
                    DatePicker("알림 시각", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .environment(\.locale, .current)
                }
            }

            DozyListRow(title: "저녁 일정 체크") {
                settingIcon("checklist")
            } trailing: {
                Toggle("저녁 일정 체크", isOn: $eveningCheckEnabled)
                    .labelsHidden()
                    .tint(DozyColor.Brand.primary)
            }
        }
        .animation(.snappy(duration: 0.25), value: reminderSettings.isEnabled)
        .onChange(of: reminderSettings) { _, newValue in applyReminderSettings(newValue) }
        .alert("알림 권한이 꺼져 있어요", isPresented: $showReminderDeniedAlert) {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text("설정 > 알림에서 Dozy의 알림을 허용한 뒤 다시 켜 주세요.")
        }
    }

    /// hour/minute ↔ DatePicker 의 Date.
    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { reminderSettings.timeAsDate },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderSettings.hour = parts.hour ?? 21
                reminderSettings.minute = parts.minute ?? 0
            }
        )
    }

    private func applyReminderSettings(_ settings: SummaryReminderSettings) {
        settings.save()
        Task { @MainActor in
            let granted = await container.summaryReminderService.apply(settings)
            if settings.isEnabled, !granted {
                reminderSettings.isEnabled = false   // onChange 재진입 → 해제 경로로 정리됨
                showReminderDeniedAlert = true
            }
        }
    }

    // MARK: - 잠금화면 섹션

    private var lockScreenSection: some View {
        DozyListSection(
            header: "잠금화면",
            footer: "오늘 시간제 일정이 있으면 잠금화면과 다이나믹 아일랜드에 진행 중·다음 일정을 보여줘요. 앱을 열 때 시작되고 마지막 일정이 끝나면 사라져요."
        ) {
            DozyListRow(title: "오늘 일정 Live Activity") {
                settingIcon("platter.filled.top.iphone")
            } trailing: {
                Toggle("오늘 일정 Live Activity", isOn: $liveActivityEnabled)
                    .labelsHidden()
                    .tint(DozyColor.Brand.primary)
            }
        }
        .onChange(of: liveActivityEnabled) { _, enabled in applyLiveActivitySetting(enabled) }
    }

    private func applyLiveActivitySetting(_ enabled: Bool) {
        LiveActivitySettings.setEnabled(enabled)
        Task { @MainActor in
            if enabled {
                _ = await container.syncTodayLiveActivityUseCase.execute()
            } else {
                await container.syncTodayLiveActivityUseCase.endAll()
            }
        }
    }
    #endif

    // MARK: - 카테고리 섹션

    private var categorySection: some View {
        DozyListSection(header: "카테고리") {
            NavigationLink {
                CategoryManagementView()
            } label: {
                DozyListRow(title: "카테고리 관리") {
                    settingIcon("square.grid.2x2")
                } trailing: {
                    DozyChevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 앱 정보 섹션

    private var infoSection: some View {
        DozyListSection(header: "앱 정보") {
            Button {
                guard let url = privacyPolicyURL,
                      let topVC = UIApplication.shared.topViewController else { return }
                let safari = SFSafariViewController(url: url)
                topVC.present(safari, animated: true)
            } label: {
                DozyListRow(title: "개인정보 처리방침") {
                    settingIcon("lock.shield")
                } trailing: {
                    DozyChevron()
                }
            }
            .buttonStyle(.plain)
            .disabled(privacyPolicyURL == nil)

            DozyListRow(title: "AI 엔진") {
                settingIcon("sparkles", accent: true)
            } trailing: {
                // 온디바이스 모델(Apple Intelligence) 사용 가능 여부 / 불가 사유
                DozyTrailingValue(text: container.aiService.engineStatus.displayName)
            }

            DozyListRow(title: "사용 통계 전송") {
                settingIcon("chart.bar.xaxis")
            } trailing: {
                // 익명 사용 통계 (#90). 끄면 Firebase Analytics 수집을 즉시 멈춘다.
                Toggle("사용 통계 전송", isOn: $analyticsEnabled)
                    .labelsHidden()
                    .tint(DozyColor.Brand.primary)
            }
            .onChange(of: analyticsEnabled) { _, enabled in
                container.setUsageDataCollectionEnabled(enabled)
            }

            DozyListRow(title: "버전") {
                settingIcon("info.circle")
            } trailing: {
                DozyTrailingValue(text: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
            }
        }
    }

    // MARK: - 비밀번호 변경 섹션 (이메일 로그인 사용자 한정)

    @ViewBuilder
    private var passwordChangeSection: some View {
        DozyListSection(header: "비밀번호") {
            Button {
                showPasswordChange = true
            } label: {
                DozyListRow(title: "비밀번호 변경") {
                    settingIcon("key.fill")
                } trailing: {
                    DozyChevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 계정 탈퇴 섹션

    @ViewBuilder
    private var dangerZoneSection: some View {
        if authViewModel.isLoggedIn {
            DozyListSection(footer: "탈퇴 시 모든 데이터가 영구 삭제되며 복구할 수 없습니다.") {
                Button {
                    showDeleteAccountAlert = true
                } label: {
                    DozyListRow(
                        title: "계정 탈퇴",
                        titleColor: DozyColor.State.danger
                    ) {
                        settingIcon("person.crop.circle.badge.xmark")
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 캘린더 섹션

    private var calendarSection: some View {
        DozyListSection(header: "캘린더") {
            NavigationLink {
                CalendarSettingsView(
                    sourceManager: container.calendarSourceManager,
                    googleSignInService: container.googleSignInService,
                    naverSignInService: container.naverSignInService
                )
            } label: {
                DozyListRow(title: "캘린더 연동") {
                    settingIcon("calendar.badge.plus")
                } trailing: {
                    DozyChevron()
                }
            }
            .buttonStyle(.plain)

            if authViewModel.isLoggedIn {
                NavigationLink {
                    SharedCalendarListView(container: container)
                } label: {
                    DozyListRow(title: "공유 캘린더") {
                        settingIcon("person.2")
                    } trailing: {
                        DozyChevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
