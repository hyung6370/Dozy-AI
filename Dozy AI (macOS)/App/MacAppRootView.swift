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
            await authViewModel.restoreSession()
        }
    }
}
