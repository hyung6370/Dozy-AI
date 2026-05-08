//
//  MacLoginView.swift
//  Dozy AI (macOS)
//
//  Apple Sign in + Email/Password. M4.2 에서 Google 버튼 추가 예정.
//

import SwiftUI

struct MacLoginView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var otpCode: String = ""
    @State private var mode: Mode = .signIn

    enum Mode { case signIn, signUp, forgotPassword }

    /// 비밀번호 단계 (signUp 또는 forgotPassword) 에서 confirm 이 password 와 다르면 true.
    private var passwordMismatch: Bool {
        (mode == .signUp || mode == .forgotPassword)
            && !passwordConfirm.isEmpty && passwordConfirm != password
    }

    /// signUp 모드의 현재 step.
    private var currentSignUpStep: MacAuthViewModel.EmailOTPStep {
        authViewModel.emailOTPStep
    }

    /// forgotPassword 모드의 현재 step.
    private var currentResetStep: MacAuthViewModel.EmailOTPStep {
        authViewModel.passwordResetStep
    }

    /// 현재 모드가 OTP-after 비밀번호 단계 (검증 완료) 여부.
    private var isPasswordStageReady: Bool {
        switch mode {
        case .signUp:          if case .verified = currentSignUpStep { return true }
        case .forgotPassword:  if case .verified = currentResetStep  { return true }
        case .signIn:          return false
        }
        return false
    }

    /// 활성 step (현재 모드의 OTP step).
    private var activeStep: MacAuthViewModel.EmailOTPStep {
        mode == .forgotPassword ? currentResetStep : currentSignUpStep
    }

    /// 활성 카운트다운 만료 시각.
    private var activeOtpExpiresAt: Date? {
        mode == .forgotPassword ? authViewModel.passwordResetExpiresAt : authViewModel.otpExpiresAt
    }

    /// 가입/로그인/재설정 버튼 활성화 조건.
    private var canSubmit: Bool {
        guard !authViewModel.isSigningIn, !email.isEmpty else { return false }
        switch mode {
        case .signIn:
            return !password.isEmpty
        case .signUp, .forgotPassword:
            guard isPasswordStageReady else { return false }
            return PasswordPolicy.isValid(password, email: email)
                && passwordConfirm == password
        }
    }

    /// 이메일이 비어 있는 채로 다른 필드를 먼저 입력한 상태면 true.
    private var needsEmailFirst: Bool {
        email.isEmpty && (!password.isEmpty || !passwordConfirm.isEmpty || !otpCode.isEmpty)
    }

    /// 클라이언트 카운트다운이 만료됐는지 — 활성 모드의 expiresAt 기준.
    private var otpExpired: Bool {
        guard let expiresAt = activeOtpExpiresAt else { return false }
        return Date() >= expiresAt
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
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

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image("Dozy-AI-60x60")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("Dozy on Mac")
                    .font(.largeTitle).bold()
                Text("파트너와 함께 하루를 설계하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            emailPasswordSection

            dividerWithLabel

            // 시스템 SignInWithAppleButton 을 쓰지 않고 우리 AuthService 만 호출.
            // SignInWithAppleButton 을 쓰면 기본 request 와 우리 request 가 동시에
            // 실행되어 Apple 이 "Sign up not completed" 로 중단시키는 경우가 있다.
            // borderedProminent + .tint(.black) 를 쓰면 윈도우가 inactive 가 됐을 때
            // 시스템이 fill·텍스트를 모두 desaturate 해서 버튼이 사실상 사라진다.
            // .plain + 수동 background 로 active 상태와 무관하게 색을 고정.
            // 다크모드에선 라이트모드와 색을 반전 — 어두운 윈도우 배경에 검정 버튼이
            // 묻히는 걸 막고 흰 배경 + 검정 텍스트로 가독성 확보.
            Button {
                authViewModel.signInWithApple()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Apple로 로그인")
                        .fontWeight(.medium)
                }
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .frame(width: 280, height: 44)
                .background(
                    colorScheme == .dark ? Color.white : Color.black,
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isSigningIn)

            Button {
                authViewModel.signInWithGoogle()
            } label: {
                HStack(spacing: 8) {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Google로 로그인")
                        .fontWeight(.medium)
                }
                .frame(width: 280, height: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(authViewModel.isSigningIn)

            if authViewModel.isSigningIn {
                ProgressView().controlSize(.small)
            }

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: 280)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            BlobBackgroundView(intensity: 0.6)
                .ignoresSafeArea()
        }
    }

    // MARK: - Email / Password

    private var emailPasswordSection: some View {
        VStack(spacing: 10) {
            // 모드 헤더 — signIn/signUp 은 picker, forgotPassword 는 뒤로가기 버튼.
            if mode == .forgotPassword {
                HStack {
                    Button {
                        switchTo(.signIn)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.caption)
                            Text("로그인으로 돌아가기").font(.caption)
                        }
                    }
                    .buttonStyle(.link)
                    Spacer()
                }
                .frame(width: 280)
                Text("비밀번호 찾기")
                    .font(.headline)
                    .frame(width: 280, alignment: .leading)
            } else {
                Picker("", selection: $mode) {
                    Text("로그인").tag(Mode.signIn)
                    Text("회원가입").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                .labelsHidden()
                .onChange(of: mode) { _, newMode in
                    // 모드 전환 시 비밀번호 / OTP / 진행중 플로우 모두 리셋.
                    password = ""
                    passwordConfirm = ""
                    otpCode = ""
                    authViewModel.errorMessage = nil
                    if newMode == .signIn {
                        authViewModel.cancelEmailOTPFlow()
                    }
                }
            }

            // ── 이메일 입력 줄 (OTP 모드면 우측에 코드 받기/변경 버튼) ──
            HStack(spacing: 6) {
                TextField("이메일", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: isOTPMode ? 196 : 280)
                    .disableAutocorrection(true)
                    .disabled(isOTPMode && activeStep != .idle)
                    .onSubmit {
                        if isOTPMode, activeStep == .idle {
                            sendOTPIfReady()
                        } else {
                            submit()
                        }
                    }

                if isOTPMode {
                    Button {
                        if activeStep == .idle {
                            sendOTPIfReady()
                        } else {
                            cancelActiveOTPFlow()
                            otpCode = ""
                            password = ""
                            passwordConfirm = ""
                        }
                    } label: {
                        Text(activeStep == .idle ? "코드 받기" : "변경")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 78, height: 24)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isSigningIn || (activeStep == .idle && email.isEmpty))
                }
            }

            if needsEmailFirst {
                Text("이메일을 먼저 입력해주세요.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 280, alignment: .leading)
            }

            // 검증 완료 표시.
            if isPasswordStageReady {
                Text(mode == .forgotPassword ? "✓ 인증 완료. 새 비밀번호를 설정하세요." : "✓ 사용 가능한 이메일입니다.")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(width: 280, alignment: .leading)
            }

            // ── OTP 입력 단계 ─────────────────────────────────
            if isOTPMode, case .otpSent(let pendingEmail) = activeStep {
                Text("\(pendingEmail) 로 보낸 6자리 코드를 입력하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 280, alignment: .leading)

                HStack(spacing: 6) {
                    TextField("인증 코드 (6자리)", text: $otpCode)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 196)
                        .disableAutocorrection(true)
                        .disabled(otpExpired)
                        .onSubmit { verifyOTPIfReady() }

                    Button {
                        verifyOTPIfReady()
                    } label: {
                        Text("확인")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 78, height: 24)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isSigningIn || otpCode.count < 6 || otpExpired)
                }

                // 카운트다운 (3분).
                if let expiresAt = activeOtpExpiresAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(expiresAt.timeIntervalSince(context.date).rounded()))
                        if remaining > 0 {
                            Text("코드 입력까지 \(formatRemaining(remaining)) 남음")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(width: 280, alignment: .leading)
                        } else {
                            Text("입력 시간이 지났어요. 코드를 다시 받아주세요.")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(width: 280, alignment: .leading)
                        }
                    }
                }

                Button("코드 다시 받기") {
                    otpCode = ""
                    sendOTPIfReady()
                }
                .buttonStyle(.link)
                .font(.caption)
                .frame(width: 280, alignment: .leading)
                .disabled(authViewModel.isSigningIn)
            }

            // ── 비밀번호 입력 단계 ────────────────────────────
            // signIn 은 항상 노출, signUp/forgotPassword 는 OTP 검증 완료 후에만.
            if mode == .signIn || isPasswordStageReady {
                SecureField(
                    mode == .signIn ? "비밀번호" : "새 비밀번호 (\(PasswordPolicy.minLength)자 이상)",
                    text: $password
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .onSubmit { submit() }

                // signUp/forgotPassword 모드 — 정책 체크리스트.
                if mode != .signIn, !password.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        passwordRule(
                            "\(PasswordPolicy.minLength)자 이상",
                            passed: PasswordPolicy.hasValidLength(password)
                        )
                        passwordRule(
                            "영문 대문자 포함",
                            passed: PasswordPolicy.hasUppercase(password)
                        )
                        passwordRule(
                            "숫자 포함",
                            passed: PasswordPolicy.hasDigit(password)
                        )
                        passwordRule(
                            "기호 포함",
                            passed: PasswordPolicy.hasSpecial(password)
                        )
                        passwordRule(
                            "흔하지 않고 이메일과 다른 비밀번호",
                            passed: PasswordPolicy.isNotCommon(password)
                                && PasswordPolicy.isNotSameAsEmail(password, email: email)
                        )
                    }
                    .frame(width: 280, alignment: .leading)
                }

                if mode != .signIn {
                    SecureField("비밀번호 확인", text: $passwordConfirm)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                        .textContentType(.newPassword)
                        .onSubmit { submit() }

                    if passwordMismatch {
                        Text("비밀번호가 일치하지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(width: 280, alignment: .leading)
                    }
                }

                Button {
                    submit()
                } label: {
                    Text(submitLabel)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 280, height: 36)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)

                // signIn 모드에서만 "비밀번호를 잊으셨나요?" 링크.
                if mode == .signIn {
                    Button("비밀번호를 잊으셨나요?") {
                        switchTo(.forgotPassword)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .frame(width: 280, alignment: .trailing)
                }
            }
        }
    }

    /// 모드의 OTP 흐름 사용 여부 (signUp + forgotPassword).
    private var isOTPMode: Bool {
        mode == .signUp || mode == .forgotPassword
    }

    /// 제출 버튼 라벨.
    private var submitLabel: String {
        switch mode {
        case .signIn:          return "이메일로 로그인"
        case .signUp:          return "가입 완료"
        case .forgotPassword:  return "비밀번호 변경"
        }
    }

    /// 모드 전환 + 입력값 / OTP 흐름 정리.
    private func switchTo(_ newMode: Mode) {
        // 현재 모드의 OTP 흐름이 살아있으면 정리.
        cancelActiveOTPFlow()
        password = ""
        passwordConfirm = ""
        otpCode = ""
        authViewModel.errorMessage = nil
        mode = newMode
    }

    /// 활성 모드의 OTP 흐름 취소.
    private func cancelActiveOTPFlow() {
        switch mode {
        case .signUp:          authViewModel.cancelEmailOTPFlow()
        case .forgotPassword:  authViewModel.cancelPasswordResetFlow()
        case .signIn:          break
        }
    }

    private func sendOTPIfReady() {
        guard !email.isEmpty, !authViewModel.isSigningIn else { return }
        authViewModel.errorMessage = nil
        switch mode {
        case .signUp:          authViewModel.sendEmailOTP(email: email)
        case .forgotPassword:  authViewModel.sendPasswordResetOTP(email: email)
        case .signIn:          break
        }
    }

    private func verifyOTPIfReady() {
        guard otpCode.count >= 6, !authViewModel.isSigningIn else { return }
        authViewModel.errorMessage = nil
        switch mode {
        case .signUp:          authViewModel.verifyEmailOTP(email: email, code: otpCode)
        case .forgotPassword:  authViewModel.verifyPasswordResetOTP(email: email, code: otpCode)
        case .signIn:          break
        }
    }

    private func submit() {
        guard canSubmit else { return }
        authViewModel.errorMessage = nil
        switch mode {
        case .signIn:
            authViewModel.signInWithEmail(email: email, password: password)
        case .signUp:
            authViewModel.completeEmailSignUp(password: password)
        case .forgotPassword:
            authViewModel.completePasswordReset(password: password)
        }
    }

    private var dividerWithLabel: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.quaternary).frame(height: 1)
            Text("또는")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().fill(.quaternary).frame(height: 1)
        }
        .frame(width: 280)
    }
}
