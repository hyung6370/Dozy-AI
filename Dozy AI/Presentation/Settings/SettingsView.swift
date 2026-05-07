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
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""
    @State private var loginPasswordConfirm: String = ""
    @State private var loginOTPCode: String = ""
    @State private var emailLoginMode: EmailLoginMode = .signIn
    private let container: DependencyContainer

    enum EmailLoginMode { case signIn, signUp, forgotPassword }

    /// signUp/forgotPassword 모드에서 confirm 이 password 와 다르면 true.
    private var passwordMismatch: Bool {
        (emailLoginMode == .signUp || emailLoginMode == .forgotPassword)
            && !loginPasswordConfirm.isEmpty && loginPasswordConfirm != loginPassword
    }

    /// 이메일이 비어 있는 채로 다른 필드를 먼저 입력한 상태면 true.
    private var needsEmailFirst: Bool {
        loginEmail.isEmpty && (!loginPassword.isEmpty || !loginPasswordConfirm.isEmpty || !loginOTPCode.isEmpty)
    }

    /// 모드의 OTP 흐름 사용 여부.
    private var isOTPMode: Bool {
        emailLoginMode == .signUp || emailLoginMode == .forgotPassword
    }

    /// 활성 step (현재 모드의 OTP step).
    private var activeStep: AuthViewModel.EmailOTPStep {
        emailLoginMode == .forgotPassword ? authViewModel.passwordResetStep : authViewModel.emailOTPStep
    }

    /// 활성 카운트다운 만료 시각.
    private var activeOtpExpiresAt: Date? {
        emailLoginMode == .forgotPassword ? authViewModel.passwordResetExpiresAt : authViewModel.otpExpiresAt
    }

    /// OTP 검증 완료 → 비밀번호 단계 활성화 여부.
    private var isPasswordStageReady: Bool {
        if case .verified = activeStep { return true }
        return false
    }

    /// 클라이언트 카운트다운 만료 여부.
    private var otpExpired: Bool {
        guard let expiresAt = activeOtpExpiresAt else { return false }
        return Date() >= expiresAt
    }

    /// 제출 버튼 라벨.
    private var submitLabel: String {
        switch emailLoginMode {
        case .signIn:          return "이메일로 로그인"
        case .signUp:          return "가입 완료"
        case .forgotPassword:  return "비밀번호 변경"
        }
    }

    /// 활성 버튼 조건.
    private var canSubmitEmailLogin: Bool {
        guard !authViewModel.isLoading, !loginEmail.isEmpty else { return false }
        switch emailLoginMode {
        case .signIn:
            return !loginPassword.isEmpty
        case .signUp, .forgotPassword:
            guard isPasswordStageReady else { return false }
            return PasswordPolicy.isValid(loginPassword, email: loginEmail)
                && loginPasswordConfirm == loginPassword
        }
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

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
        NavigationStack {
            List {
                accountSection
                calendarSection
                categorySection
                infoSection
                if authViewModel.currentUser?.provider == .email {
                    passwordChangeSection
                }
                dangerZoneSection
            }
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
        Section {
            if authViewModel.isLoggedIn {
                loggedInRow
            } else {
                loggedOutRow
            }
        } header: {
            Text("계정")
        } footer: {
            Text(authViewModel.isLoggedIn
                 ? "로그인 상태에서는 데이터가 서버에 백업됩니다."
                 : "로그인하면 기기를 바꿔도 데이터를 유지할 수 있어요.")
        }
    }
    
    private var loggedInRow: some View {
        HStack(spacing: 14) {
            providerIcon(for: authViewModel.currentUser?.provider)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(authViewModel.currentUser?.displayName ?? "사용자")
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
    
    private var loggedOutRow: some View {
        VStack(spacing: 12) {
            // Apple 로그인 (DEBUG 개발 환경에서는 미지원)
            #if DEBUG
            if AppEnvironment.current != .development {
                Button { authViewModel.signInWithApple() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .medium))
                        Text("Apple로 로그인")
                            .font(.subheadline).fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                }
                .buttonStyle(.plain)
            }
            #else
            Button { authViewModel.signInWithApple() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .medium))
                    Text("Apple로 로그인")
                        .font(.subheadline).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color(uiColor: .systemBackground))
            }
            .buttonStyle(.plain)
            #endif

            // Google 로그인
            Button { authViewModel.signInWithGoogle() } label: {
                HStack(spacing: 10) {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Google로 로그인")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            emailPasswordLoginBlock
        }
        .padding(.vertical, 8)
        // 로딩 중에도 폼 (이메일·OTP·비밀번호) 은 그대로 보이게 — 사용자가 지금
        // 어느 단계에서 무엇을 입력했는지 시각적으로 유지. 위에 머티리얼 카드로
        // 감싼 ProgressView 만 overlay 로 띄움.
        .disabled(authViewModel.isLoading)
        .overlay {
            if authViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
    }

    private var emailPasswordLoginBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                Text("또는")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
            }
            .padding(.top, 4)

            // 모드 헤더 — signIn/signUp 은 picker, forgotPassword 는 뒤로 가기 + 타이틀.
            if emailLoginMode == .forgotPassword {
                HStack {
                    Button {
                        switchEmailLoginMode(to: .signIn)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.caption)
                            Text("로그인으로 돌아가기").font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    Spacer()
                }
                Text("비밀번호 찾기")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Picker("", selection: $emailLoginMode) {
                    Text("로그인").tag(EmailLoginMode.signIn)
                    Text("회원가입").tag(EmailLoginMode.signUp)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: emailLoginMode) { _, newMode in
                    loginPassword = ""
                    loginPasswordConfirm = ""
                    loginOTPCode = ""
                    authViewModel.errorMessage = nil
                    if newMode == .signIn {
                        authViewModel.cancelEmailOTPFlow()
                    }
                }
            }

            // ── 이메일 입력 + (OTP 모드) 코드받기/변경 버튼 ─────────
            HStack(spacing: 6) {
                TextField("이메일", text: $loginEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .disabled(isOTPMode && activeStep != .idle)
                    .onSubmit {
                        if isOTPMode, activeStep == .idle {
                            sendOTPIfReady()
                        } else {
                            submitEmailLogin()
                        }
                    }

                if isOTPMode {
                    Button {
                        if activeStep == .idle {
                            sendOTPIfReady()
                        } else {
                            cancelActiveOTPFlow()
                            loginOTPCode = ""
                            loginPassword = ""
                            loginPasswordConfirm = ""
                        }
                    } label: {
                        Text(activeStep == .idle ? "코드 받기" : "변경")
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isLoading || (activeStep == .idle && loginEmail.isEmpty))
                }
            }

            if needsEmailFirst {
                Text("이메일을 먼저 입력해주세요.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 검증 완료 표시.
            if isPasswordStageReady {
                Text(emailLoginMode == .forgotPassword ? "✓ 인증 완료. 새 비밀번호를 설정하세요." : "✓ 사용 가능한 이메일입니다.")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ── OTP 입력 단계 ─────────────────────────────────
            if isOTPMode, case .otpSent(let pendingEmail) = activeStep {
                Text("\(pendingEmail) 로 보낸 6자리 코드를 입력하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    TextField("인증 코드 (6자리)", text: $loginOTPCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .disabled(otpExpired)
                        .onSubmit { verifyOTPIfReady() }

                    Button {
                        verifyOTPIfReady()
                    } label: {
                        Text("확인")
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isLoading || loginOTPCode.count < 6 || otpExpired)
                }

                // 카운트다운 (3분).
                if let expiresAt = activeOtpExpiresAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(expiresAt.timeIntervalSince(context.date).rounded()))
                        if remaining > 0 {
                            Text("코드 입력까지 \(formatRemaining(remaining)) 남음")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("입력 시간이 지났어요. 코드를 다시 받아주세요.")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Button("코드 다시 받기") {
                    loginOTPCode = ""
                    sendOTPIfReady()
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(authViewModel.isLoading)
            }

            // ── 비밀번호 입력 단계 ────────────────────────────
            // signIn 은 항상 노출, signUp/forgotPassword 는 OTP 검증 완료 후에만.
            if emailLoginMode == .signIn || isPasswordStageReady {
                SecureField(
                    emailLoginMode == .signIn ? "비밀번호" : "새 비밀번호 (\(PasswordPolicy.minLength)자 이상)",
                    text: $loginPassword
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(emailLoginMode == .signIn ? .password : .newPassword)
                .submitLabel(emailLoginMode == .signIn ? .go : .next)
                .onSubmit { submitEmailLogin() }

                // signUp/forgotPassword — 정책 체크리스트.
                if emailLoginMode != .signIn, !loginPassword.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        passwordRule(
                            "\(PasswordPolicy.minLength)자 이상",
                            passed: PasswordPolicy.hasValidLength(loginPassword)
                        )
                        passwordRule(
                            "영문 대문자 포함",
                            passed: PasswordPolicy.hasUppercase(loginPassword)
                        )
                        passwordRule(
                            "숫자 포함",
                            passed: PasswordPolicy.hasDigit(loginPassword)
                        )
                        passwordRule(
                            "기호 포함",
                            passed: PasswordPolicy.hasSpecial(loginPassword)
                        )
                        passwordRule(
                            "흔하지 않고 이메일과 다른 비밀번호",
                            passed: PasswordPolicy.isNotCommon(loginPassword)
                                && PasswordPolicy.isNotSameAsEmail(loginPassword, email: loginEmail)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if emailLoginMode != .signIn {
                    SecureField("비밀번호 확인", text: $loginPasswordConfirm)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .submitLabel(.join)
                        .onSubmit { submitEmailLogin() }

                    if passwordMismatch {
                        Text("비밀번호가 일치하지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    submitEmailLogin()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text(submitLabel)
                            .font(.subheadline).fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitEmailLogin)

                // signIn 에서만 "비밀번호를 잊으셨나요?" 링크.
                if emailLoginMode == .signIn {
                    Button("비밀번호를 잊으셨나요?") {
                        switchEmailLoginMode(to: .forgotPassword)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    /// 모드 전환 + 입력값 / OTP 흐름 정리.
    private func switchEmailLoginMode(to newMode: EmailLoginMode) {
        cancelActiveOTPFlow()
        loginPassword = ""
        loginPasswordConfirm = ""
        loginOTPCode = ""
        authViewModel.errorMessage = nil
        emailLoginMode = newMode
    }

    /// 활성 모드의 OTP 흐름 취소.
    private func cancelActiveOTPFlow() {
        switch emailLoginMode {
        case .signUp:          authViewModel.cancelEmailOTPFlow()
        case .forgotPassword:  authViewModel.cancelPasswordResetFlow()
        case .signIn:          break
        }
    }

    private func sendOTPIfReady() {
        guard !loginEmail.isEmpty, !authViewModel.isLoading else { return }
        authViewModel.errorMessage = nil
        switch emailLoginMode {
        case .signUp:          authViewModel.sendEmailOTP(email: loginEmail)
        case .forgotPassword:  authViewModel.sendPasswordResetOTP(email: loginEmail)
        case .signIn:          break
        }
    }

    private func verifyOTPIfReady() {
        guard loginOTPCode.count >= 6, !authViewModel.isLoading else { return }
        authViewModel.errorMessage = nil
        switch emailLoginMode {
        case .signUp:          authViewModel.verifyEmailOTP(email: loginEmail, code: loginOTPCode)
        case .forgotPassword:  authViewModel.verifyPasswordResetOTP(email: loginEmail, code: loginOTPCode)
        case .signIn:          break
        }
    }

    private func submitEmailLogin() {
        guard canSubmitEmailLogin else { return }
        authViewModel.errorMessage = nil
        switch emailLoginMode {
        case .signIn:
            authViewModel.signInWithEmail(email: loginEmail, password: loginPassword)
        case .signUp:
            authViewModel.completeEmailSignUp(password: loginPassword)
        case .forgotPassword:
            authViewModel.completePasswordReset(password: loginPassword)
        }
    }

    /// 비밀번호 정책 체크리스트 한 줄 — 통과 시 초록 ✓, 미통과 시 회색 원.
    private func passwordRule(_ label: String, passed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(passed ? .green : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(passed ? .primary : .secondary)
        }
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
    
    // MARK: - 카테고리 섹션

    private var categorySection: some View {
        Section {
            NavigationLink {
                CategoryManagementView()
            } label: {
                Label { Text("카테고리 관리") } icon: {
                    settingIcon("Light-Management-Category", "Dark-Management-Category")
                }
            }
        } header: {
            Text("카테고리")
        }
    }

    // MARK: - 앱 정보 섹션

    private var infoSection: some View {
        Section {
            Button {
                guard let url = privacyPolicyURL,
                      let topVC = UIApplication.shared.topViewController else { return }
                let safari = SFSafariViewController(url: url)
                topVC.present(safari, animated: true)
            } label: {
                Label { Text("개인정보 처리방침") } icon: {
                    settingIcon("Light-Privacy", "Dark-Privacy")
                }
            }
            .foregroundStyle(.primary)
            .disabled(privacyPolicyURL == nil)

            HStack {
                Label { Text("버전") } icon: {
                    settingIcon("Light-Version", "Dark-Version")
                }
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("앱 정보")
        }
    }

    // MARK: - 비밀번호 변경 섹션 (이메일 로그인 사용자 한정)

    @ViewBuilder
    private var passwordChangeSection: some View {
        Section {
            Button {
                showPasswordChange = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("비밀번호 변경")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("비밀번호")
        }
    }

    // MARK: - 계정 탈퇴 섹션

    @ViewBuilder
    private var dangerZoneSection: some View {
        if authViewModel.isLoggedIn {
            Section {
                Button(role: .destructive) {
                    showDeleteAccountAlert = true
                } label: {
                    Label { Text("계정 탈퇴") } icon: {
                        settingIcon("Light-Delete-Account", "Dark-Delete-Account")
                    }
                }
            } footer: {
                Text("탈퇴 시 모든 데이터가 영구 삭제되며 복구할 수 없습니다.")
            }
        }
    }

    // MARK: - 캘린더 섹션

    private var calendarSection: some View {
        Section {
            NavigationLink {
                CalendarSettingsView(
                    sourceManager: container.calendarSourceManager,
                    googleSignInService: container.googleSignInService,
                    naverSignInService: container.naverSignInService
                )
            } label: {
                Label { Text("캘린더 연동") } icon: {
                    settingIcon("Light-Integrate-Calendar", "Dark-Integrate-Calendar")
                }
            }
            if authViewModel.isLoggedIn {
                NavigationLink {
                    SharedCalendarListView(container: container)
                } label: {
                    Label { Text("공유 캘린더") } icon: {
                        settingIcon("Light-Share-Calendar", "Dark-Share-Calendar")
                    }
                }
            }
        } header: {
            Text("캘린더")
        }
    }
}
