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

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: AuthUser? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showCongratulationAnimation = false

    private let authService = AuthService()
    private let syncService: SyncService
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext) {
        self.syncService = SyncService(modelContext: modelContext)
    }

    var isLoggedIn: Bool { currentUser != nil }

    func restoreSession() {
        authService.restoreSession()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                if let user {
                    self?.syncAfterLogin(userID: user.id)
                }
            }
            .store(in: &cancellables)
    }

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
                    self?.showCongratulationAnimation = true
                    self?.syncAfterLogin(userID: user.id)
                }
            )
            .store(in: &cancellables)
    }

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
                    self?.showCongratulationAnimation = true
                    self?.syncAfterLogin(userID: user.id)
                }
            )
            .store(in: &cancellables)
    }

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

    func signOut() {
        authService.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] in
                    self?.currentUser = nil
                }
            )
            .store(in: &cancellables)
    }
}
