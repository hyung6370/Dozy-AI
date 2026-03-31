//
//  NaverSignInService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/31/26.
//

import Foundation
import Combine
import NaverThirdPartyLogin

final class NaverSignInService: NSObject, ObservableObject {
    
    @Published private(set) var isSignedIn = false
    @Published private(set) var userEmail: String?
    @Published private(set) var userName: String?
    
    private let instance = NaverThirdPartyLoginConnection.getSharedInstance()
    private var signInSubject: PassthroughSubject<Void, DozyError>?
    
    override init() {
        super.init()
        setupSDK()
        checkPreviousSignIn()
    }
    
    // MARK: - Setup
    
    private func setupSDK() {
        guard let clientID = Bundle.main.infoDictionary?["NAVER_CLIENT_ID"] as? String,
              let clientSecret = Bundle.main.infoDictionary?["NAVER_CLIENT_SECRET"] as? String else { return }
        
        instance?.isNaverAppOauthEnable = true
        instance?.isInAppOauthEnable = true
        instance?.serviceUrlScheme = "naverlogin-\(clientID)"
        instance?.consumerKey = clientID
        instance?.consumerSecret = clientSecret
        instance?.appName = "Dozy AI"
        instance?.delegate = self
    }
    
    private func checkPreviousSignIn() {
        guard let inst = instance,
              inst.isValidAccessTokenExpireTimeNow() else { return }
        DispatchQueue.main.async {
            self.isSignedIn = true
        }
    }
    
    // MARK: - Public
    
    func signIn() -> AnyPublisher<Void, DozyError> {
        let subject = PassthroughSubject<Void, DozyError>()
        signInSubject = subject
        instance?.requestThirdPartyLogin()
        return subject.eraseToAnyPublisher()
    }
    
    func signOut() {
        instance?.requestDeleteToken()
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userEmail = nil
            self.userName = nil
        }
    }
    
    func getValidAccessToken() -> AnyPublisher<String, DozyError> {
        Future<String, DozyError> { [weak self] promise in
            guard let inst = self?.instance else {
                promise(.failure(.naverSignInFailed))
                return
            }
            if inst.isValidAccessTokenExpireTimeNow() {
                promise(.success(inst.accessToken ?? ""))
            } else {
                inst.requestAccessTokenWithRefreshToken()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    promise(.success(inst.accessToken ?? ""))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - URL 처리
    func handle(url: URL) {
        NaverThirdPartyLoginConnection.getSharedInstance()?.receiveAccessToken(url)
    }
}

// MARK: - NaverThirdPartyLoginConnectionDelegate

extension NaverSignInService: NaverThirdPartyLoginConnectionDelegate {
    
    func oauth20ConnectionDidFinishRequestACTokenWithAuthCode() {
        if let token = instance?.accessToken {
            fetchUserProfile(accessToken: token)
        }
        DispatchQueue.main.async {
            self.isSignedIn = true
        }
        signInSubject?.send(())
        signInSubject?.send(completion: .finished)
        signInSubject = nil
    }
    
    private func fetchUserProfile(accessToken: String) {
        guard let url = URL(string: "https://openapi.naver.com/v1/nid/me") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["response"] as? [String: Any] else { return }
            
            let email = response["email"] as? String
            let name = response["name"] as? String
            
            DispatchQueue.main.async {
                self?.userEmail = email
                self?.userName = name
            }
        }.resume()
    }
    
    func oauth20ConnectionDidFinishRequestACTokenWithRefreshToken() {
        DispatchQueue.main.async { self.isSignedIn = true }
    }
    
    func oauth20ConnectionDidFinishDeleteToken() {
        DispatchQueue.main.async { self.isSignedIn = false }
    }
    
    func oauth20Connection(_ oauthConnection: NaverThirdPartyLoginConnection!, didFailWithError error: Error!) {
        signInSubject?.send(completion: .failure(.naverSignInFailed))
        signInSubject = nil
    }
}
