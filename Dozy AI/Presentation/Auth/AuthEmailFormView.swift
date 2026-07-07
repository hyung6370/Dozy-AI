//
//  AuthEmailFormView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 7/2/26.
//

import SwiftUI

/// 이메일 로그인/회원가입/비밀번호 찾기 폼.
/// AuthSheetView 안에서 "이메일로 계속하기" 를 누르면 등장한다.
/// 입력값·실패 카운터는 모두 이 뷰의 @State 라 시트가 닫히면 자동 초기화된다.
struct AuthEmailFormView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel

    enum EmailLoginMode { case signIn, signUp, forgotPassword }

    /// signIn 모드에서 연속 비밀번호 실패 횟수를 관리하는 limiter. 5회 이상이면 안내 banner 노출 +
    /// "비밀번호를 잊으셨나요?" 링크 강조 + 로그인 버튼 비활성. 로그인 성공/이메일 변경 시 reset.
    @State private var emailPasswordLimiter = PasswordFailLimiter(threshold: 5)
    /// limit 도달 시 자동 표시되는 안내 alert.
    @State private var showFailLimitAlert: Bool = false
    /// 이메일 로그인 제출이 진행 중인지 — Apple/Google 등 다른 경로의 errorMessage 는 카운트에서 제외.
    @State private var emailSignInInFlight: Bool = false
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""
    @State private var loginPasswordConfirm: String = ""
    @State private var loginOTPCode: String = ""
    @State private var emailLoginMode: EmailLoginMode = .signIn

    // MARK: - Derived State

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

    /// 제출 버튼 라벨. `String(localized:)` 로 wrap — `Text(_:String)` 경로로 빠져 추출되지
    /// 않는 것을 막는다.
    private var submitLabel: String {
        switch emailLoginMode {
        case .signIn:          return String(localized: "이메일로 로그인")
        case .signUp:          return String(localized: "가입 완료")
        case .forgotPassword:  return String(localized: "비밀번호 변경")
        }
    }

    /// 활성 버튼 조건.
    private var canSubmitEmailLogin: Bool {
        guard !authViewModel.isLoading, !loginEmail.isEmpty else { return false }
        switch emailLoginMode {
        case .signIn:
            // limit 도달 시 비활성 — 사용자는 이메일 인증으로만 진행 가능.
            guard emailPasswordLimiter.canSubmit else { return false }
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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            modeHeader

            // ── 이메일 입력 + (OTP 모드) 코드받기/변경 버튼 ─────────
            HStack(spacing: 6) {
                TextField("이메일", text: $loginEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .dozyAuthFieldStyle()
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

            otpStage
            passwordStage
        }
        // signIn 모드 + 이메일 로그인 제출이 in-flight 일 때만 비밀번호 실패로 간주.
        // (Apple/Google 취소 등으로 errorMessage 가 생기는 경우는 카운트 제외)
        .onChange(of: authViewModel.errorMessage) { _, newVal in
            if newVal != nil, emailLoginMode == .signIn, emailSignInInFlight {
                emailPasswordLimiter.recordFailure()
                if emailPasswordLimiter.justReachedLimit {
                    showFailLimitAlert = true
                }
                emailSignInInFlight = false
            }
        }
        // 로딩 종료 시 in-flight 해제 (성공 / 다른 경로 종료 둘 다).
        .onChange(of: authViewModel.isLoading) { _, newVal in
            if !newVal { emailSignInInFlight = false }
        }
        // 이메일 변경 시 카운터 reset. (로그인 성공 시에는 시트가 닫히며 @State 전체가 소멸)
        .onChange(of: loginEmail) { _, _ in
            emailPasswordLimiter.reset()
        }
        .alert("비밀번호를 \(emailPasswordLimiter.threshold)회 틀리셨습니다", isPresented: $showFailLimitAlert) {
            Button("이메일 인증하기") {
                switchEmailLoginMode(to: .forgotPassword)
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("보안을 위해 이메일 인증 후 비밀번호를 재설정해주세요.")
        }
    }

    // MARK: - Sub Views

    /// 모드 헤더 — signIn/signUp 은 picker, forgotPassword 는 뒤로 가기 + 타이틀.
    @ViewBuilder
    private var modeHeader: some View {
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
    }

    /// OTP 입력 단계.
    @ViewBuilder
    private var otpStage: some View {
        if isOTPMode, case .otpSent(let pendingEmail) = activeStep {
            Text("\(pendingEmail) 로 보낸 6자리 코드를 입력하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                TextField("인증 코드 (6자리)", text: $loginOTPCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .dozyAuthFieldStyle()
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
    }

    /// 비밀번호 입력 단계.
    /// signIn 은 항상 노출, signUp/forgotPassword 는 OTP 검증 완료 후에만.
    @ViewBuilder
    private var passwordStage: some View {
        if emailLoginMode == .signIn || isPasswordStageReady {
            // 비밀번호 실패 카운트 표시. 1회 이상이면 작은 안내, threshold 이상이면 강조 banner.
            if emailLoginMode == .signIn && emailPasswordLimiter.count > 0 {
                let isReset = emailPasswordLimiter.hasReachedLimit
                HStack(spacing: 8) {
                    Image(systemName: isReset ? "lock.rotation" : "exclamationmark.circle")
                        .font(.subheadline)
                    Text(
                        isReset
                            ? "비밀번호 \(emailPasswordLimiter.count)회 틀렸어요. 재설정해보세요."
                            : "비밀번호 \(emailPasswordLimiter.count)회 틀렸어요."
                    )
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                }
                .foregroundStyle(isReset ? Color.accentColor : Color.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    (isReset ? Color.accentColor : Color.red).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }

            SecureField(
                emailLoginMode == .signIn ? "비밀번호" : "새 비밀번호 (\(PasswordPolicy.minLength)자 이상)",
                text: $loginPassword
            )
            .dozyAuthFieldStyle()
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
                    .dozyAuthFieldStyle()
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
                }
            }
            .buttonStyle(DozyAuthPrimaryButtonStyle())
            .disabled(!canSubmitEmailLogin)

            // signIn 에서만 "비밀번호를 잊으셨나요?" 링크.
            // 5회 이상 실패 시 굵게 강조해서 시선 끌기.
            if emailLoginMode == .signIn {
                HStack {
                    Spacer()
                    Button("비밀번호를 잊으셨나요?") {
                        switchEmailLoginMode(to: .forgotPassword)
                    }
                    .font(.caption)
                    .fontWeight(emailPasswordLimiter.hasReachedLimit ? .bold : .regular)
                    .foregroundStyle(Color.accentColor)
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    /// 비밀번호 정책 체크리스트 한 줄 — 통과 시 초록 ✓, 미통과 시 회색 원.
    private func passwordRule(_ label: LocalizedStringKey, passed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(passed ? .green : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(passed ? .primary : .secondary)
        }
    }

    // MARK: - Actions

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
            // 이메일 로그인 제출만 표시 — onChange(errorMessage) 가 이걸 보고
            // 비밀번호 실패만 카운트하고 Apple/Google 등은 무시한다.
            emailSignInInFlight = true
            authViewModel.signInWithEmail(email: loginEmail, password: loginPassword)
        case .signUp:
            authViewModel.completeEmailSignUp(password: loginPassword)
        case .forgotPassword:
            authViewModel.completePasswordReset(password: loginPassword)
        }
    }
}
