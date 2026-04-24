//
//  MacMenuBarIcon.swift
//  Dozy AI (macOS)
//
//  M4.10 — MenuBarExtra 의 라벨로 표시되는 아이콘.
//  오늘 남은 일정 수를 배지로 노출 (사용자가 설정에서 끄면 숨김).
//

import SwiftUI

struct MacMenuBarIcon: View {
    @ObservedObject var viewModel: MacMenuBarViewModel
    @AppStorage("menuBarShowBadge") private var showBadge: Bool = true

    var body: some View {
        if showBadge && viewModel.remainingCount > 0 {
            Label("\(viewModel.remainingCount)", systemImage: "calendar")
        } else {
            Image(systemName: "calendar")
        }
    }
}
