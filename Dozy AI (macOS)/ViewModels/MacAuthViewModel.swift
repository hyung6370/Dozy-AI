//
//  MacAuthViewModel.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 4/23/26.
//

import Foundation
import Combine
import SwiftData
import Supabase
import OSLog

@MainActor
final class MacAuthViewModel: ObservableObject {
    
    enum State {
        case loading
        case signedOut
        case signedIn(AuthUser)
    }
    
    @Published var state: State = .loading
    @Published var errorMessage: String?
    @Published var isSigningIn = false
    
    private let authService: AuthService
    private let modelContainer: ModelContainer
    private let syncService: SyncService
    private var cancellables = Set<AnyCancellable>()

    var currentUser: AuthUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    init(authService: AuthService, modelContainer: ModelContainer) {
        self.authService = authService
        self.modelContainer = modelContainer
        self.syncService = SyncService(modelContext: modelContainer.mainContext)
    }

    // MARK: - Sign-in success + sync

    /// 로그인/세션 복원 성공 시 공통 처리 — 상태 전환 후 Supabase 동기화 트리거.
    private func completeSignIn(_ user: AuthUser) {
        state = .signedIn(user)
        syncAfterLogin(userID: user.id)
    }

    private func syncAfterLogin(userID: String) {
        syncService.syncAll(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.sync.error("❌ syncAll 실패: \(error.localizedDescription)")
                    }
                },
                receiveValue: { _ in
                    Logger.sync.info("✅ syncAll 완료 → dozyDataSyncCompleted")
                    NotificationCenter.default.post(name: .dozyDataSyncCompleted, object: nil)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Session
    
    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            let providerString = session.user.appMetadata["provider"]?.stringValue ?? ""
            let provider: AuthProvider = {
                switch providerString {
                case "google": return .google
                case "email":  return .email
                default:       return .apple
                }
            }()
            let user = AuthUser(
                id: session.user.id.uuidString.lowercased(),
                email: session.user.email,
                displayName: nil,
                provider: provider
            )
            completeSignIn(user)
        } catch {
            state = .signedOut
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        
        authService.signInWithApple()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                }, receiveValue: { [weak self] user in
                    self?.state = .signedIn(user)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Google Sign In

    func signInWithGoogle() {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil

        authService.signInWithGoogle()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.completeSignIn(user)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Email / Password

    func signInWithEmail(email: String, password: String) {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil

        authService.signInWithEmail(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.completeSignIn(user)
                }
            )
            .store(in: &cancellables)
    }

    func signUpWithEmail(email: String, password: String) {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil

        authService.signUpWithEmail(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.completeSignIn(user)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Sign out

    func signOut() {
        authService.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    // 로컬 SwiftData 전체 삭제 — 다른 계정으로 로그인했을 때 이전 사용자의
                    // UserCategory(userID 컬럼 없음) / DozyEvent / WorkLog 가 잔존해서
                    // 카테고리 목록·통계가 섞이는 것 방지.
                    self.syncService.clearAllLocalData()
                    self.state = .signedOut
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 회원탈퇴

    func deleteAccount() {
        authService.deleteAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.state = .signedOut
                }
            )
            .store(in: &cancellables)
    }
}
