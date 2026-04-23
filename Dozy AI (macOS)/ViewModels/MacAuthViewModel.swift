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
    private var cancellables = Set<AnyCancellable>()
    
    var currentUser: AuthUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }
    
    init(authService: AuthService, modelContainer: ModelContainer) {
        self.authService = authService
        self.modelContainer = modelContainer
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
            state = .signedIn(user)
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
                    self?.state = .signedIn(user)
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
                    self?.state = .signedIn(user)
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
                    self?.state = .signedIn(user)
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
                    self?.state = .signedOut
                }
            )
            .store(in: &cancellables)
    }
}
