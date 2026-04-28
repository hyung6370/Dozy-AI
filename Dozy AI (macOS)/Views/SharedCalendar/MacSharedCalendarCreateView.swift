//
//  MacSharedCalendarCreateView.swift
//  Dozy AI (macOS)
//
//  M4.8b — 공유 캘린더 생성 시트. 이름 입력 후 생성 → 초대 코드 표시.
//

import SwiftUI

struct MacSharedCalendarCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SharedCalendarViewModel

    @State private var calendarName = ""
    @State private var submittedName = ""
    @State private var creationResult: SharedCalendarCreationResult? = nil
    @State private var copied = false

    private var isNameValid: Bool {
        !calendarName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            if let result = creationResult {
                successView(result: result)
            } else {
                createForm
            }
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 340)
    }

    // MARK: - Create Form

    private var createForm: some View {
        Form {
            Section {
                TextField("예: 우리 커플 캘린더", text: $calendarName)
                    .onSubmit { if isNameValid { submit() } }
            } header: {
                Text("캘린더 이름")
            } footer: {
                Text("파트너와 함께 사용할 캘린더 이름을 입력하세요.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("공유 캘린더 만들기")
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
                        Text("만들기")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isNameValid || viewModel.isLoading)
            }
        }
    }

    private func submit() {
        let trimmed = calendarName.trimmingCharacters(in: .whitespaces)
        submittedName = trimmed
        viewModel.create(name: trimmed) { result in
            creationResult = result
        }
    }

    // MARK: - Success

    private func successView(result: SharedCalendarCreationResult) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("공유 캘린더가 생성되었습니다!")
                .font(.headline)

            VStack(spacing: 6) {
                Text(submittedName)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("초대 코드")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text(result.inviteCode)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        copyCode(result.inviteCode)
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("파트너에게 이 코드를 전달해 주세요.\n코드는 상세 화면에서 재생성할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("완료") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("생성 완료")
    }

    private func copyCode(_ code: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
