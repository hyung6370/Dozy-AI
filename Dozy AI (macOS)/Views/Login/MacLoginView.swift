//
//  MacLoginView.swift
//  Dozy AI (macOS)
//
//  Apple Sign in + Email/Password. M4.2 에서 Google 버튼 추가 예정.
//

import SwiftUI

struct MacLoginView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var otpCode: String = ""
    @State private var mode: Mode = .signIn

    enum Mode { case signIn, signUp }

    /// 회원가입 모드에서 confirm 필드가 채워졌는데 password 와 다르면 true.
    /// signIn 모드이거나 confirm 이 비어있으면 false → 입력 도중 경고가 깜빡이지 않게.
    private var passwordMismatch: Bool {
        mode == .signUp && !passwordConfirm.isEmpty && passwordConfirm != password
    }

    /// signUp 모드의 현재 step (idle / otpSent / verified) 을 ViewModel 에서 읽음.
    private var currentSignUpStep: MacAuthViewModel.EmailOTPStep {
        authViewModel.emailOTPStep
    }

    /// OTP 검증 완료 → 비밀번호 단계 활성화 여부.
    private var isPasswordStageReady: Bool {
        if case .verified = currentSignUpStep { return true }
        return false
    }

    /// 가입/로그인 버튼 활성화 조건. signUp 은 OTP 검증 완료 + 비밀번호 일치 필요.
    private var canSubmit: Bool {
        guard !authViewModel.isSigningIn, !email.isEmpty else { return false }
        if mode == .signUp {
            guard isPasswordStageReady else { return false }
            return !password.isEmpty && !passwordConfirm.isEmpty && passwordConfirm == password
        }
        return !password.isEmpty
    }

    /// 이메일이 비어 있는 채로 다른 필드를 먼저 입력한 상태면 true.
    private var needsEmailFirst: Bool {
        email.isEmpty && (!password.isEmpty || !passwordConfirm.isEmpty || !otpCode.isEmpty)
    }

    /// 클라이언트 카운트다운이 만료됐는지 — view body 가 직접 Date 비교하면 stale.
    /// TimelineView 가 매초 redraw 시켜주므로 그 안의 비교가 실시간 반영.
    private var otpExpired: Bool {
        guard let expiresAt = authViewModel.otpExpiresAt else { return false }
        return Date() >= expiresAt
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
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
            Button {
                authViewModel.signInWithApple()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Apple로 로그인")
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .frame(width: 280, height: 44)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
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
    }

    // MARK: - Email / Password

    private var emailPasswordSection: some View {
        VStack(spacing: 10) {
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

            // ── 이메일 입력 줄 (signUp 모드면 우측에 코드 받기/변경 버튼) ──
            HStack(spacing: 6) {
                TextField("이메일", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: mode == .signUp ? 196 : 280)
                    .disableAutocorrection(true)
                    .disabled(mode == .signUp && currentSignUpStep != .idle)
                    .onSubmit {
                        if mode == .signUp, currentSignUpStep == .idle {
                            sendOTPIfReady()
                        } else {
                            submit()
                        }
                    }

                if mode == .signUp {
                    Button {
                        if currentSignUpStep == .idle {
                            sendOTPIfReady()
                        } else {
                            // OTP 입력 중 / 검증 완료 상태에서 → 처음부터 다시.
                            authViewModel.cancelEmailOTPFlow()
                            otpCode = ""
                            password = ""
                            passwordConfirm = ""
                        }
                    } label: {
                        Text(currentSignUpStep == .idle ? "코드 받기" : "변경")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 78, height: 24)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isSigningIn || (currentSignUpStep == .idle && email.isEmpty))
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
                Text("✓ 사용 가능한 이메일입니다.")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(width: 280, alignment: .leading)
            }

            // ── OTP 입력 단계 ─────────────────────────────────
            if mode == .signUp, case .otpSent(let pendingEmail) = currentSignUpStep {
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

                // 카운트다운 (3분) — 매초 갱신.
                if let expiresAt = authViewModel.otpExpiresAt {
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
                    authViewModel.sendEmailOTP(email: email)
                }
                .buttonStyle(.link)
                .font(.caption)
                .frame(width: 280, alignment: .leading)
                .disabled(authViewModel.isSigningIn)
            }

            // ── 비밀번호 입력 단계 ────────────────────────────
            // signIn 은 항상 노출, signUp 은 OTP 검증 완료 후에만.
            if mode == .signIn || isPasswordStageReady {
                SecureField("비밀번호 (6자 이상)", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                    .onSubmit { submit() }

                if mode == .signUp {
                    SecureField("비밀번호 확인", text: $passwordConfirm)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
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
                    Text(mode == .signIn ? "이메일로 로그인" : "가입 완료")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 280, height: 36)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        }
    }

    private func sendOTPIfReady() {
        guard !email.isEmpty, !authViewModel.isSigningIn else { return }
        authViewModel.errorMessage = nil
        authViewModel.sendEmailOTP(email: email)
    }

    private func verifyOTPIfReady() {
        guard otpCode.count >= 6, !authViewModel.isSigningIn else { return }
        authViewModel.errorMessage = nil
        authViewModel.verifyEmailOTP(email: email, code: otpCode)
    }

    private func submit() {
        guard canSubmit else { return }
        authViewModel.errorMessage = nil
        switch mode {
        case .signIn:
            authViewModel.signInWithEmail(email: email, password: password)
        case .signUp:
            authViewModel.completeEmailSignUp(password: password)
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
