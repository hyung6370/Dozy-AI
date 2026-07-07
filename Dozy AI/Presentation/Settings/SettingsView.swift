//
//  SettingsView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/6/26.
//

import SwiftUI
import Lottie
import SafariServices

struct SettingsView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private func settingIcon(_ lightName: String, _ darkName: String) -> some View {
        Image(colorScheme == .dark ? darkName : lightName)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
    }
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showPasswordChange = false
    /// DragGesture 기반 커스텀 로그인 시트 (AuthSheetView) 표시 여부.
    @State private var showLoginSheet = false
    @AppStorage(DozyBackgroundTheme.storageKey, store: DozyBackgroundTheme.sharedDefaults)
    private var backgroundThemeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var backgroundTheme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    private let container: DependencyContainer

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
        // 로그인 성공 → 시트 닫기. 축하 Lottie 는 settingsContent 의 overlay 에서 재생.
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
            // system 일 때는 grouped, ambient/blob 일 땐 themed bg — modifier 가 단일 layer 로 처리.
            .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if authViewModel.showCongratulationAnimation {
                    LottieView(name: "congratulation", loopMode: .playOnce) {
                        authViewModel.showCongratulationAnimation = false
                    }
                    .scaleEffect(0.3)
                    .allowsHitTesting(false)
                }
            }
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
                Image(colorScheme == .dark ? "Dark-User-Add-Line" : "Light-User-Add-Line")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
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
            Image(systemName: "apple.logo")
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
            Image(systemName: "envelope.fill")
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
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DozyColor.Brand.primary)
                        .frame(width: 22, height: 22)
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

    // MARK: - 카테고리 섹션

    private var categorySection: some View {
        DozyListSection(header: "카테고리") {
            NavigationLink {
                CategoryManagementView()
            } label: {
                DozyListRow(title: "카테고리 관리") {
                    settingIcon("Light-Management-Category", "Dark-Management-Category")
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
                    settingIcon("Light-Privacy", "Dark-Privacy")
                } trailing: {
                    DozyChevron()
                }
            }
            .buttonStyle(.plain)
            .disabled(privacyPolicyURL == nil)

            DozyListRow(title: "버전") {
                settingIcon("Light-Version", "Dark-Version")
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
                    Image(systemName: "key.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DozyColor.Text.secondary)
                        .frame(width: 22, height: 22)
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
                        settingIcon("Light-Delete-Account", "Dark-Delete-Account")
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
                    settingIcon("Light-Integrate-Calendar", "Dark-Integrate-Calendar")
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
                        settingIcon("Light-Share-Calendar", "Dark-Share-Calendar")
                    } trailing: {
                        DozyChevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
