//
//  GoogleSignInService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Foundation
import Combine
import GoogleSignIn

final class GoogleSignInService: ObservableObject {
    
    @Published private(set) var isSignedIn = false
    @Published private(set) var userEmail: String?
    @Published private(set) var userName: String?
    
    private let scopes = [
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
    ]
    
    init() {
        restorePreviousSignIn()
    }
    
    // MARK: - Public
    
    func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            DispatchQueue.main.async {
                self?.updateState(user: user)
            }
        }
    }
    
    func signIn(presenting viewController: UIViewController) -> AnyPublisher<Void, DozyError> {
        Future { [weak self] promise in
            guard let self else { return }
            GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: self.scopes
            ) { result, error in
                if let error {
                    promise(.failure(.googleSignInFailed(underlying: error)))
                    return
                }
                DispatchQueue.main.async {
                    self.updateState(user: result?.user)
                }
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userEmail = nil
            self.userName = nil
        }
    }
    
    func getValidAccessToken() -> AnyPublisher<String, DozyError> {
        Future { promise in
            guard let user = GIDSignIn.sharedInstance.currentUser else {
                promise(.failure(.googleSignInFailed(underlying: nil)))
                return
            }
            user.refreshTokensIfNeeded { refreshed, error in
                if let error {
                    promise(.failure(.googleSignInFailed(underlying: error)))
                    return
                }
                guard let token = refreshed?.accessToken.tokenString else {
                    promise(.failure(.googleSignInFailed(underlying: nil)))
                    return
                }
                promise(.success(token))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private
    private func updateState(user: GIDGoogleUser?) {
        let wasSignedIn = isSignedIn
        isSignedIn = user != nil
        userEmail = user?.profile?.email
        userName = user?.profile?.name
        // 로그인 미완료 → 완료 전환 시 캘린더 새로고침 트리거
        if !wasSignedIn && isSignedIn {
            NotificationCenter.default.post(name: .googleSignInRestored, object: nil)
        }
    }
}
