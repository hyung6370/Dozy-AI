//
//  AuthService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation
import Combine
import OSLog
import Supabase
import AuthenticationServices
import GoogleSignIn
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import CryptoKit

final class AuthService: NSObject {

    // MARK: - Apple 로그인

    func signInWithApple() -> AnyPublisher<AuthUser, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            let nonce = self.randomNonceString()
            let hashedNonce = self.sha256(nonce)

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            AppleSignInDelegate.shared.currentNonce = nonce
            AppleSignInDelegate.shared.onComplete = { result in
                switch result {
                case .failure(let error):
                    promise(.failure(.unknown(underlying: error)))
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let identityToken = credential.identityToken,
                          let tokenString = String(data: identityToken, encoding: .utf8) else {
                        promise(.failure(.unknown(underlying: NSError(domain: "AuthService", code: -1))))
                        return
                    }
                    Task {
                        do {
                            let session = try await supabase.auth.signInWithIdToken(
                                credentials: .init(provider: .apple, idToken: tokenString, nonce: nonce)
                            )
                            let user = AuthUser(
                                id: session.user.id.uuidString.lowercased(),
                                email: session.user.email,
                                displayName: credential.fullName?.givenName,
                                provider: .apple
                            )
                            promise(.success(user))
                        } catch {
                            promise(.failure(.unknown(underlying: error)))
                        }
                    }
                }
            }

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = AppleSignInDelegate.shared
            controller.presentationContextProvider = AppleSignInDelegate.shared
            controller.performRequests()
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Google 로그인

    /// iOS 는 topViewController, macOS 는 keyWindow 를 presenting anchor 로 넘겨
    /// GoogleSignIn SDK 의 네이티브 ID Token 플로우를 사용한다. redirect_uri 방식이 아니므로
    /// Web 타입 OAuth 클라이언트 / Supabase "Client ID (for OAuth)" 설정은 불필요.
    func signInWithGoogle() -> AnyPublisher<AuthUser, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            let nonce = self.randomNonceString()
            let hashedNonce = self.sha256(nonce)

            let completion: (GIDSignInResult?, Error?) -> Void = { result, error in
                if let error {
                    promise(.failure(.googleSignInFailed(underlying: error)))
                    return
                }
                guard let idToken = result?.user.idToken?.tokenString,
                      let accessToken = result?.user.accessToken.tokenString else {
                    promise(.failure(.unknown(underlying: NSError(domain: "AuthService", code: -1))))
                    return
                }
                let displayName = result?.user.profile?.name
                let email = result?.user.profile?.email
                Task {
                    do {
                        let session = try await supabase.auth.signInWithIdToken(
                            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken, nonce: nonce)
                        )
                        let user = AuthUser(
                            id: session.user.id.uuidString.lowercased(),
                            email: email ?? session.user.email,
                            displayName: displayName,
                            provider: .google
                        )
                        promise(.success(user))
                    } catch {
                        promise(.failure(.unknown(underlying: error)))
                    }
                }
            }

            #if os(iOS)
            guard let topVC = UIApplication.shared.topViewController else {
                promise(.failure(.unknown(underlying: NSError(domain: "AuthService", code: -1))))
                return
            }
            GIDSignIn.sharedInstance.signIn(
                withPresenting: topVC,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce,
                completion: completion
            )
            #elseif os(macOS)
            guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
                promise(.failure(.unknown(underlying: NSError(domain: "AuthService", code: -1))))
                return
            }
            GIDSignIn.sharedInstance.signIn(
                withPresenting: window,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce,
                completion: completion
            )
            #endif
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Email / Password 로그인

    /// 이메일/비밀번호로 로그인. 계정이 없으면 .emailAuthFailed 로 실패하므로
    /// 호출자는 필요 시 signUpWithEmail 를 이어 호출할 수 있다.
    func signInWithEmail(email: String, password: String) -> AnyPublisher<AuthUser, DozyError> {
        Future { promise in
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            #if DEBUG
            let pwTrim = password.trimmingCharacters(in: .whitespacesAndNewlines)
            Logger.auth.debug("📧 signIn attempt email='\(normalizedEmail)' pwLen=\(password.count) pwTrimmedLen=\(pwTrim.count) env=\(AppEnvironment.current.displayName)")
            #endif
            if let validationError = Self.validate(email: normalizedEmail, password: password) {
                promise(.failure(validationError))
                return
            }
            Task {
                do {
                    let session = try await supabase.auth.signIn(email: normalizedEmail, password: password)
                    let user = AuthUser(
                        id: session.user.id.uuidString.lowercased(),
                        email: session.user.email,
                        displayName: nil,
                        provider: .email
                    )
                    promise(.success(user))
                } catch {
                    #if DEBUG
                    Logger.auth.error("🔴 signIn failed: \(error.localizedDescription)")
                    #endif
                    promise(.failure(Self.mapSignInError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 이메일/비밀번호로 신규 가입. Supabase 프로젝트에서 이메일 확인이 꺼져 있으면
    /// 즉시 세션이 반환되고, 켜져 있으면 session 이 nil 인 상태에서 확인 메일 링크 클릭을 기다린다.
    func signUpWithEmail(email: String, password: String) -> AnyPublisher<AuthUser, DozyError> {
        Future { promise in
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            #if DEBUG
            Logger.auth.debug("📧 signUp attempt email='\(normalizedEmail)' pwLen=\(password.count) env=\(AppEnvironment.current.displayName)")
            #endif
            if let validationError = Self.validate(email: normalizedEmail, password: password) {
                promise(.failure(validationError))
                return
            }
            Task {
                do {
                    let response = try await supabase.auth.signUp(email: normalizedEmail, password: password)
                    let authUser = response.user
                    if (authUser.identities ?? []).isEmpty {
                        promise(.failure(.emailAlreadyRegistered))
                        return
                    }
                    let user = AuthUser(
                        id: authUser.id.uuidString.lowercased(),
                        email: authUser.email,
                        displayName: nil,
                        provider: .email
                    )
                    promise(.success(user))
                } catch {
                    #if DEBUG
                    Logger.auth.error("🔴 signUp failed: \(error.localizedDescription)")
                    #endif
                    promise(.failure(Self.mapSignUpError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Email OTP (이메일 사전 검증 흐름)

    /// auth.users 에 해당 이메일이 이미 존재하는지 확인. Supabase 에 정의된
    /// public.check_email_exists(text) → bool RPC 호출.
    func checkEmailExists(email: String) -> AnyPublisher<Bool, DozyError> {
        Future { promise in
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            Task {
                do {
                    let exists: Bool = try await supabase
                        .rpc("check_email_exists", params: ["email_to_check": normalizedEmail])
                        .execute()
                        .value
                    promise(.success(exists))
                } catch {
                    #if DEBUG
                    Logger.auth.error("🔴 check_email_exists failed: \(error.localizedDescription)")
                    #endif
                    promise(.failure(.emailAuthFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 이메일 검증용 OTP 코드 발송. 이미 가입된 이메일이면 .emailAlreadyRegistered 로
    /// 실패시켜 호출자가 안내. 신규 이메일만 OTP 발송 (shouldCreateUser: true 로
    /// passwordless user 즉시 생성, 검증 후 비밀번호 별도 set).
    func sendEmailOTP(email: String) -> AnyPublisher<Void, DozyError> {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        #if DEBUG
        Logger.auth.debug("📧 OTP send → email='\(normalizedEmail)' env=\(AppEnvironment.current.displayName)")
        #endif
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        if normalizedEmail.range(of: emailRegex, options: .regularExpression) == nil {
            return Fail(error: .emailInvalid).eraseToAnyPublisher()
        }
        // 1) 이미 가입된 이메일이면 OTP 보내지 말고 즉시 실패.
        return checkEmailExists(email: normalizedEmail)
            .flatMap { exists -> AnyPublisher<Void, DozyError> in
                if exists {
                    return Fail(error: .emailAlreadyRegistered).eraseToAnyPublisher()
                }
                // 2) 신규 이메일 → OTP 발송.
                return Future<Void, DozyError> { promise in
                    Task {
                        do {
                            try await supabase.auth.signInWithOTP(
                                email: normalizedEmail,
                                shouldCreateUser: true
                            )
                            promise(.success(()))
                        } catch {
                            #if DEBUG
                            Logger.auth.error("🔴 OTP send failed: \(error.localizedDescription)")
                            #endif
                            promise(.failure(.emailAuthFailed(underlying: error)))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// OTP 코드 검증. 성공 시 사용자가 signed-in 상태가 되며, 호출자는 이어서
    /// `setPasswordForCurrentSession` 으로 비밀번호를 부여해야 한다.
    func verifyEmailOTP(email: String, code: String) -> AnyPublisher<Void, DozyError> {
        Future { promise in
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                do {
                    _ = try await supabase.auth.verifyOTP(
                        email: normalizedEmail,
                        token: trimmedCode,
                        type: .email
                    )
                    promise(.success(()))
                } catch {
                    #if DEBUG
                    Logger.auth.error("🔴 OTP verify failed: \(error.localizedDescription)")
                    #endif
                    promise(.failure(.emailInvalidCredentials))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// OTP 검증 후 현재 signed-in 세션에 비밀번호 설정 + signup_completed marker 기록.
    /// 이 marker 가 있어야 pg_cron 의 미인증 사용자 정리 작업이 이 사용자를 보호한다
    /// (Supabase 가 signInWithOTP 시점에 email_confirmed_at 등 모든 컬럼을 채워버려서
    /// 클라이언트 측 마커 외엔 가입 완료 여부를 구분할 방법이 없음).
    func setPasswordForCurrentSession(_ password: String) -> AnyPublisher<AuthUser, DozyError> {
        Future { promise in
            if password.count < 6 {
                promise(.failure(.passwordTooShort))
                return
            }
            Task {
                do {
                    let updatedUser = try await supabase.auth.update(
                        user: UserAttributes(
                            password: password,
                            data: ["signup_completed": .bool(true)]
                        )
                    )
                    let user = AuthUser(
                        id: updatedUser.id.uuidString.lowercased(),
                        email: updatedUser.email,
                        displayName: nil,
                        provider: .email
                    )
                    promise(.success(user))
                } catch {
                    #if DEBUG
                    Logger.auth.error("🔴 password set failed: \(error.localizedDescription)")
                    #endif
                    promise(.failure(.emailAuthFailed(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private static func mapSignInError(_ error: Error) -> DozyError {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login credentials") || msg.contains("invalid_credentials") {
            return .emailInvalidCredentials
        }
        return .emailAuthFailed(underlying: error)
    }

    private static func mapSignUpError(_ error: Error) -> DozyError {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("already registered") || msg.contains("user already") || msg.contains("user_already_exists") {
            return .emailAlreadyRegistered
        }
        return .emailAuthFailed(underlying: error)
    }

    private static func validate(email: String, password: String) -> DozyError? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        if trimmed.range(of: emailRegex, options: .regularExpression) == nil {
            return .emailInvalid
        }
        if password.count < 6 {
            return .passwordTooShort
        }
        return nil
    }

    // MARK: - 로그아웃

    func signOut() -> AnyPublisher<Void, DozyError> {
        Future { promise in
            Task {
                do {
                    try await supabase.auth.signOut()
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 회원탈퇴
    func deleteAccount() -> AnyPublisher<Void, DozyError> {
        Future { promise in
            Task {
                do {
                    try await supabase.rpc("delete_user_account").execute()
                    promise(.success(()))
                } catch {
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign In Delegate

final class AppleSignInDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    static let shared = AppleSignInDelegate()
    var onComplete: ((Result<ASAuthorization, Error>) -> Void)?
    var currentNonce: String?

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        onComplete?(.success(authorization))
        onComplete = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        onComplete?(.failure(error))
        onComplete = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
        #elseif os(macOS)
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        #endif
    }
}

