//
//  MacRootView.swift
//  Dozy AI (macOS)
//
//  M4.1 placeholder — M4.3 에서 NavigationSplitView 로 교체.
//

import SwiftUI

struct MacRootView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("로그인 성공")
                .font(.largeTitle).bold()
            if let email = authViewModel.currentUser?.email {
                Text(email)
                    .foregroundStyle(.secondary)
            }
            Text("M4.3 에서 NavigationSplitView 로 교체 예정")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("로그아웃") {
                authViewModel.signOut()
            }
            .buttonStyle(.bordered)
            .padding(.top, 12)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
