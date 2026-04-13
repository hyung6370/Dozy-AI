//
//  AuthViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation
import Combine
import SwiftData
import OSLog
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: AuthUser? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showCongratulationAnimation = false

    private let authService = AuthService()
    private let syncService: SyncService
    private var cancellables = Set<AnyCancellable>()

    /// Keychain에 displayName을 저장할 때 사용하는 키.
    /// Supabase SDK는 토큰만 관리하고 displayName은 세션에 포함되지 않으므로
    /// 별도로 Keychain에 보관합니다.
    private static let displayNameKey = "auth.displayName"

    init(modelContext: ModelContext) {
        self.syncService = SyncService(modelContext: modelContext)
    }

    var isLoggedIn: Bool { currentUser != nil }

    // MARK: - Auth State Listener

    /// 앱 시작 시 한 번 호출합니다.
    /// supabase.auth.authStateChanges 스트림을 구독해:
    /// - .initialSession : Keychain에 저장된 세션으로 자동 로그인 (토큰 만료 시 SDK가 자동 갱신)
    /// - .tokenRefreshed : 액세스 토큰 갱신 완료 로그
    /// - .signedOut      : 세션 만료 또는 명시적 로그아웃 → 사용자 상태 초기화
    func startAuthListener() {
        Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .initialSession:
                    guard let session else { return }
                    let providerString = session.user.appMetadata["provider"]?.stringValue ?? ""
                    let provider: AuthProvider = providerString == "google" ? .google : .apple
                    self.currentUser = AuthUser(
                        id: session.user.id.uuidString,
                        email: session.user.email,
                        displayName: KeychainService.load(forKey: Self.displayNameKey),
                        provider: provider
                    )
                    self.syncAfterLogin(userID: session.user.id.uuidString)

                case .tokenRefreshed:
                    Logger.auth.info("🔑 액세스 토큰 자동 갱신 완료")

                case .signedOut:
                    self.currentUser = nil
                    KeychainService.delete(forKey: Self.displayNameKey)

                default:
                    break
                }
            }
        }
    }

    // MARK: - Apple 로그인

    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        authService.signInWithApple()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    if let name = user.displayName {
                        KeychainService.save(name, forKey: Self.displayNameKey)
                    }
                    self?.showCongratulationAnimation = true
                    self?.syncAfterLogin(userID: user.id)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Google 로그인

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        authService.signInWithGoogle()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    if let name = user.displayName {
                        KeychainService.save(name, forKey: Self.displayNameKey)
                    }
                    self?.showCongratulationAnimation = true
                    self?.syncAfterLogin(userID: user.id)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 로그아웃

    func signOut() {
        authService.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] in
                    // currentUser 및 Keychain 정리는 authStateChanges .signedOut 이벤트에서도 처리되지만
                    // UX 즉시성을 위해 여기서도 명시적으로 초기화합니다.
                    self?.currentUser = nil
                    KeychainService.delete(forKey: Self.displayNameKey)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Private

    private func syncAfterLogin(userID: String) {
        Logger.auth.info("🔄 syncAfterLogin 시작 userID=\(userID)")
        syncService.syncAll(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.auth.error("❌ syncAll 실패: \(error.localizedDescription)")
                    }
                },
                receiveValue: {
                    Logger.auth.info("✅ syncAll 완료 → dozyDataSyncCompleted 전송")
                    NotificationCenter.default.post(name: .dozyDataSyncCompleted, object: nil)
                }
            )
            .store(in: &cancellables)
    }
}
