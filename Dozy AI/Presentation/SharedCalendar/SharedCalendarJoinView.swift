//
//  SharedCalendarJoinView.swift
//  Dozy AI
//

import SwiftUI

struct SharedCalendarJoinView: View {

    @ObservedObject var viewModel: SharedCalendarViewModel
    @Environment(\.dismiss) private var dismiss

    var initialCode: String = ""

    @State private var code = ""
    @State private var joined = false
    @FocusState private var isFocused: Bool

    private var isCodeValid: Bool { code.count == 6 }

    var body: some View {
        NavigationStack {
            if joined {
                successView
            } else {
                joinForm
            }
        }
    }

    // MARK: - Join Form

    private var joinForm: some View {
        VStack(spacing: 0) {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                    Text("초대 코드 입력")
                        .font(.title3).fontWeight(.bold)
                    Text("파트너에게 받은 6자리 코드를 입력하세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                codeInputField
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                submit()
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("참여하기")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    isCodeValid && !viewModel.isLoading ? Color.accentColor : Color(.systemGray4),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!isCodeValid || viewModel.isLoading)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationTitle("공유 캘린더 참여")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            if !initialCode.isEmpty { code = String(initialCode.uppercased().prefix(6)) }
            isFocused = true
        }
    }

    private var codeInputField: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                let char: String = index < code.count
                    ? String(code[code.index(code.startIndex, offsetBy: index)])
                    : ""
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 48, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(index < code.count ? Color.accentColor : Color(.systemGray4), lineWidth: 1.5)
                        )
                    Text(char)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .overlay {
            TextField("", text: $code)
                .focused($isFocused)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .onChange(of: code) { _, new in
                    code = String(new.uppercased().prefix(6))
                        .filter { $0.isLetter || $0.isNumber }
                }
                .opacity(0.01)
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            VStack(spacing: 8) {
                Text("참여 완료!")
                    .font(.title2).fontWeight(.bold)
                Text("공유 캘린더에 참여했어요.\n이제 파트너의 일정을 함께 볼 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("확인") { dismiss() }
                .font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
        .navigationTitle("참여 완료")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Submit

    private func submit() {
        viewModel.join(code: code) {
            withAnimation { joined = true }
        }
    }
}
