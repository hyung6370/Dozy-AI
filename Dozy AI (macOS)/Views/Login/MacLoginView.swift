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
    @State private var mode: Mode = .signIn

    enum Mode { case signIn, signUp }

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

            TextField("이메일", text: $email)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .disableAutocorrection(true)
                .onSubmit { submit() }

            SecureField("비밀번호 (6자 이상)", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { submit() }

            // Apple 버튼과 동일한 사유로 .plain + 수동 background.
            Button {
                submit()
            } label: {
                Text(mode == .signIn ? "이메일로 로그인" : "이메일로 가입")
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 280, height: 36)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isSigningIn || email.isEmpty || password.isEmpty)
        }
    }

    private func submit() {
        guard !authViewModel.isSigningIn,
              !email.isEmpty,
              !password.isEmpty else { return }
        authViewModel.errorMessage = nil
        switch mode {
        case .signIn:
            authViewModel.signInWithEmail(email: email, password: password)
        case .signUp:
            authViewModel.signUpWithEmail(email: email, password: password)
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
