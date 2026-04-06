//
//  AuthService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation
import Combine
import Supabase
import AuthenticationServices
import GoogleSignIn
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
                                id: session.user.id.uuidString,
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

    func signInWithGoogle() -> AnyPublisher<AuthUser, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            guard let topVC = UIApplication.shared.topViewController else {
                promise(.failure(.unknown(underlying: NSError(domain: "AuthService", code: -1))))
                return
            }
            let nonce = self.randomNonceString()
            let hashedNonce = self.sha256(nonce)

            GIDSignIn.sharedInstance.signIn(withPresenting: topVC, hint: nil, additionalScopes: nil, nonce: hashedNonce) { result, error in
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
                            id: session.user.id.uuidString,
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
        }
        .eraseToAnyPublisher()
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

    // MARK: - 세션 복원

    func restoreSession() -> AnyPublisher<AuthUser?, Never> {
        Future { promise in
            Task {
                guard let session = try? await supabase.auth.session else {
                    promise(.success(nil))
                    return
                }
                let providerString = session.user.appMetadata["provider"]?.stringValue ?? ""
                let provider: AuthProvider = providerString == "google" ? .google : .apple
                let user = AuthUser(
                    id: session.user.id.uuidString,
                    email: session.user.email,
                    displayName: nil,
                    provider: provider
                )
                promise(.success(user))
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
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
    }
}
