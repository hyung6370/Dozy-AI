//
//  MacSharedCalendarJoinView.swift
//  Dozy AI (macOS)
//
//  M4.8b — 초대 코드로 공유 캘린더 참여 시트.
//

import SwiftUI

struct MacSharedCalendarJoinView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SharedCalendarViewModel

    @State private var code: String = ""

    private var normalizedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var isCodeValid: Bool {
        normalizedCode.count >= 4
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("예: ABCD12", text: $code)
                        .font(.system(.title3, design: .monospaced))
                        .textCase(.uppercase)
                        .onSubmit { if isCodeValid { submit() } }
                } header: {
                    Text("초대 코드")
                } footer: {
                    Text("파트너로부터 받은 초대 코드를 입력하세요.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("초대 코드로 참여")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("참여")
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isCodeValid || viewModel.isLoading)
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 280)
    }

    private func submit() {
        viewModel.join(code: normalizedCode) {
            dismiss()
        }
    }
}
