//
//  PasswordChangeSheet.swift
//  Dozy AI
//
//  로그인 상태 (이메일 로그인 사용자 한정) 비밀번호 변경 sheet (iOS).
//  3-step OTP 흐름 — 본인 이메일 인증 → 새 비밀번호 정책 통과 → 변경.
//

import SwiftUI

struct PasswordChangeSheet: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirm = ""
    @State private var showSuccessAlert = false

    private var email: String {
        authViewModel.currentUser?.email ?? ""
    }

    private var step: AuthViewModel.EmailOTPStep {
        authViewModel.passwordChangeStep
    }

    private var passwordMismatch: Bool {
        !newPasswordConfirm.isEmpty && newPasswordConfirm != newPassword
    }

    private var canSubmitNewPassword: Bool {
        !authViewModel.isChangingPassword
            && PasswordPolicy.isValid(newPassword, email: email)
            && newPasswordConfirm == newPassword
    }

    private var otpExpired: Bool {
        guard let expiresAt = authViewModel.passwordChangeExpiresAt else { return false }
        return Date() >= expiresAt
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    switch step {
                    case .idle:
                        idleStep
                    case .otpSent:
                        otpStep
                    case .verified:
                        passwordStep
                    }

                    if let error = authViewModel.changePasswordError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(20)
            }
            .navigationTitle("비밀번호 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .onChange(of: authViewModel.changePasswordSucceeded) { _, succeeded in
            if succeeded {
                authViewModel.resetChangePasswordState()
                showSuccessAlert = true
            }
        }
        .onDisappear {
            authViewModel.resetChangePasswordState()
        }
        .alert("비밀번호가 변경되었어요", isPresented: $showSuccessAlert) {
            Button("확인") { dismiss() }
        }
    }

    // MARK: - Step 1 — 코드 받기

    private var idleStep: some View {
        VStack(spacing: 14) {
            Text("본인 확인을 위해 가입 이메일로 6자리 인증 코드를 보냅니다.")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(email)
                    .font(.body)
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))

            Button {
                authViewModel.sendPasswordChangeOTP(email: email)
            } label: {
                Text("코드 받기")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isChangingPassword || email.isEmpty)
        }
    }

    // MARK: - Step 2 — OTP 입력

    private var otpStep: some View {
        VStack(spacing: 12) {
            Text("\(email) 로 보낸 6자리 코드를 입력하세요.")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TextField("인증 코드 (6자리)", text: $otpCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .disabled(otpExpired)
                    .onSubmit { verifyOTPIfReady() }

                Button {
                    verifyOTPIfReady()
                } label: {
                    Text("확인")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(authViewModel.isChangingPassword || otpCode.count < 6 || otpExpired)
            }

            if let expiresAt = authViewModel.passwordChangeExpiresAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(expiresAt.timeIntervalSince(context.date).rounded()))
                    Text(remaining > 0
                         ? "코드 입력까지 \(formatRemaining(remaining)) 남음"
                         : "입력 시간이 지났어요. 코드를 다시 받아주세요.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button("코드 다시 받기") {
                otpCode = ""
                authViewModel.sendPasswordChangeOTP(email: email)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(authViewModel.isChangingPassword)
        }
    }

    // MARK: - Step 3 — 새 비밀번호

    private var passwordStep: some View {
        VStack(spacing: 12) {
            Text("✓ 인증 완료. 새 비밀번호를 설정하세요.")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)

            SecureField("새 비밀번호 (\(PasswordPolicy.minLength)자 이상)", text: $newPassword)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .textContentType(.newPassword)

            if !newPassword.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    rule("\(PasswordPolicy.minLength)자 이상", passed: PasswordPolicy.hasValidLength(newPassword))
                    rule("영문 대문자 포함", passed: PasswordPolicy.hasUppercase(newPassword))
                    rule("숫자 포함", passed: PasswordPolicy.hasDigit(newPassword))
                    rule("기호 포함", passed: PasswordPolicy.hasSpecial(newPassword))
                    rule(
                        "흔하지 않고 이메일과 다른 비밀번호",
                        passed: PasswordPolicy.isNotCommon(newPassword)
                            && PasswordPolicy.isNotSameAsEmail(newPassword, email: email)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SecureField("새 비밀번호 확인", text: $newPasswordConfirm)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .textContentType(.newPassword)

            if passwordMismatch {
                Text("비밀번호가 일치하지 않습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                authViewModel.completeInAppPasswordChange(newPassword: newPassword)
            } label: {
                Text("비밀번호 변경")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmitNewPassword)
        }
    }

    // MARK: - Helpers

    private func verifyOTPIfReady() {
        guard otpCode.count >= 6, !authViewModel.isChangingPassword else { return }
        authViewModel.verifyPasswordChangeOTP(email: email, code: otpCode)
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func rule(_ label: String, passed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundStyle(passed ? .green : .secondary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(passed ? .primary : .secondary)
        }
    }
}
