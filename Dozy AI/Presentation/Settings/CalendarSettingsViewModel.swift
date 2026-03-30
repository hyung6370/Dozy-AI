//
//  CalendarSettingsViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Combine
import UIKit

final class CalendarSettingsViewModel: ObservableObject {
    
    @Published var googleSignInError: String?
    
    let sourceManager: CalendarSourceManager
    let signInService: GoogleSignInService
    
    private var cancellables = Set<AnyCancellable>()
    
    init(sourceManager: CalendarSourceManager, signInService: GoogleSignInService) {
        self.sourceManager = sourceManager
        self.signInService = signInService
        
        signInService.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed
    var isGoogleSignedIn: Bool { signInService.isSignedIn }
    var googleUserEmail: String? { signInService.userEmail }
    
    // MARK: - Actions
    func connectGoogle() {
        guard let vc = UIApplication.shared.topViewController else { return }
        
        signInService.signIn(presenting: vc)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.googleSignInError = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.sourceManager.enable(.google)
                }
            ).store(in: &cancellables)
    }
    
    func disconnectGoogle() {
        signInService.signOut()
        sourceManager.disable(.google)
    }
    
    func toggleApple() {
        sourceManager.toggle(.apple)
    }
}
