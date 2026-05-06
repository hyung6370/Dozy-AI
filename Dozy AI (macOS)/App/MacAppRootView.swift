//
//  MacAppRootView.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 4/23/26.
//

import SwiftUI
import Lottie

struct MacAppRootView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel

    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ProgressView("세션 확인 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .signedOut:
                MacLoginView()

            case .signedIn:
                MacMainShellView()
            }
        }
        .task {
            authViewModel.startAuthListenerIfNeeded()
            await authViewModel.restoreSession()
        }
        .alert(
            "세션 만료",
            isPresented: $authViewModel.showSessionExpiredAlert
        ) {
            Button("예", role: .destructive) {
                authViewModel.confirmSessionExpiry()
            }
        } message: {
            Text("세션이 만료되어서 다시 로그인하셔야 합니다.")
        }
    }
}
