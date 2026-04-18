//
//  CalendarSettingsViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Combine
import UIKit

@MainActor
final class CalendarSettingsViewModel: ObservableObject {

    @Published var errorMessage: String?

    let sourceManager: CalendarSourceManager
    let googleSignInService: GoogleSignInService
    let naverSignInService: NaverSignInService

    private var cancellables = Set<AnyCancellable>()

    init(
        sourceManager: CalendarSourceManager,
        googleSignInService: GoogleSignInService,
        naverSignInService: NaverSignInService
    ) {
        self.sourceManager       = sourceManager
        self.googleSignInService = googleSignInService
        self.naverSignInService  = naverSignInService

        // 각 서비스 변경 시 View 갱신
        googleSignInService.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        naverSignInService.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Computed
    var isGoogleSignedIn: Bool { googleSignInService.isSignedIn }
    var googleUserEmail: String? { googleSignInService.userEmail }

    var isNaverSignedIn: Bool { naverSignInService.isSignedIn }
    var naverUserEmail: String? { naverSignInService.userEmail }

    // MARK: - Google
    func connectGoogle() {
        guard let vc = UIApplication.shared.topViewController else { return }
        googleSignInService.signIn(presenting: vc)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.sourceManager.enable(.google)
                }
            )
            .store(in: &cancellables)
    }

    func disconnectGoogle() {
        googleSignInService.signOut()
        sourceManager.disable(.google)
    }

    // MARK: - Naver
    func connectNaver() {
        naverSignInService.signIn()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.sourceManager.enable(.naver)
                }
            )
            .store(in: &cancellables)
    }

    func disconnectNaver() {
        naverSignInService.signOut()
        sourceManager.disable(.naver)
    }

    // MARK: - Apple
    func toggleApple() {
        sourceManager.toggle(.apple)
    }
}
