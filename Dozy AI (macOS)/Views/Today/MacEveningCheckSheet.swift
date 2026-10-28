//
//  MacEveningCheckSheet.swift
//  Dozy AI (macOS)
//
//  18시 이후 앱을 열었을 때 끝났는데 완료 체크가 없는 오늘 일정을 묻는 시트 (#101, iOS #63 과 같은 데이터).
//  목록은 열 때의 스냅샷(viewModel.eveningCheckEvents), 체크 상태는 completionsByEventID 로 실시간 반영.
//  크기(frame)는 호출부의 .sheet 래퍼에서 준다 — 본문 안에 두면 닫을 때 부모 창이 줄어드는 macOS 레이아웃 버그.
//

import SwiftUI

struct MacEveningCheckSheet: View {
    @ObservedObject var viewModel: MacHomeViewModel
    let onDone: () -> Void

    private var remainingCount: Int {
        viewModel.eveningCheckEvents.filter { viewModel.completionsByEventID[$0.id] != true }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("오늘 일정 어떠셨나요?")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("완료한 일정이 있다면 체크해 주세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.eveningCheckEvents) { event in
                        MacEventRow(
                            event: event,
                            isCompleted: viewModel.completionsByEventID[event.id] == true,
                            onToggleCompletion: { viewModel.toggleCompletion(for: event) }
                        )
                    }
                }
            }

            HStack {
                if remainingCount > 0 {
                    Button {
                        viewModel.completeAllEveningCheckEvents()
                    } label: {
                        Label("모두 완료", symbol: "checkmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DozyColor.Brand.primary)
                }
                Spacer()
                Button("나중에", action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("완료", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(DozyColor.Brand.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
