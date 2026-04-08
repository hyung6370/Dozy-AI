//
//  RootView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

struct RootView: View {

    let container: DependencyContainer
    @State private var showIntro = true

    var body: some View {
        ZStack {
            MainTabView(container: container)

            if showIntro {
                IntroView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showIntro = false
                    }
                }
                .zIndex(1)
            }
        }
    }
}
