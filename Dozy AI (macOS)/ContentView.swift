//
//  ContentView.swift
//  Dozy AI (macOS)
//
//  Phase M1 placeholder. 실제 뷰는 M4에서 NavigationSplitView로 교체.
//

import SwiftUI

struct MacRootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Dozy on Mac")
                .font(.largeTitle).fontWeight(.semibold)
            Text("Phase M1 — 프로젝트 구조 준비")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

#Preview {
    MacRootView()
}
