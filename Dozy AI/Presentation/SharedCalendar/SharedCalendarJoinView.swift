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
            ScrollView {
                VStack(spacing: DozySpacing.xl) {
                    VStack(spacing: DozySpacing.sm) {
                        SharedCalendarHeaderIcon(symbol: "person.badge.plus")
                        Text("초대 코드를 입력해 주세요")
                            .font(DozyFont.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(DozyColor.Text.primary)
                        Text("함께할 사람에게 받은 6자리 코드를 입력하면 바로 참여해요.")
                            .font(DozyFont.subheadline)
                            .foregroundStyle(DozyColor.Text.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DozySpacing.xl)

                    codeInputField
                }
                .padding(.horizontal, DozySpacing.lg)
            }

            Button {
                submit()
            } label: {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("참여하기")
                }
            }
            .buttonStyle(SharedCalendarPrimaryButtonStyle())
            .disabled(!isCodeValid || viewModel.isLoading)
            .padding(.horizontal, DozySpacing.lg)
            .padding(.bottom, DozySpacing.lg)
        }
        .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
        .navigationTitle("공유 캘린더 참여")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundStyle(DozyColor.Text.primary)
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
        HStack(spacing: DozySpacing.xs) {
            ForEach(0..<6, id: \.self) { index in
                let char: String = index < code.count
                    ? String(code[code.index(code.startIndex, offsetBy: index)])
                    : ""
                let isCurrent = isFocused && index == min(code.count, 5)
                Text(char)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(DozyColor.Brand.primary)
                    .frame(maxWidth: 52)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .dozyThemedCardSurface(cornerRadius: DozyRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DozyRadius.md, style: .continuous)
                            .strokeBorder(
                                index < code.count || isCurrent ? DozyColor.Brand.primary : .clear,
                                lineWidth: isCurrent ? 2 : 1.5
                            )
                    )
                    .animation(.easeOut(duration: 0.12), value: code)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
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
                .accessibilityLabel("초대 코드 6자리")
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: DozySpacing.xl) {
            Spacer()
            SharedCalendarHeaderIcon(symbol: "checkmark", size: 88)
            VStack(spacing: DozySpacing.xs) {
                Text("참여 완료!")
                    .font(DozyFont.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DozyColor.Text.primary)
                Text("공유 캘린더에 참여했어요.\n이제 구성원의 일정을 함께 볼 수 있어요.")
                    .font(DozyFont.subheadline)
                    .foregroundStyle(DozyColor.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("확인") { dismiss() }
                .buttonStyle(SharedCalendarPrimaryButtonStyle())
                .padding(.horizontal, DozySpacing.lg)
                .padding(.bottom, DozySpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
        .navigationTitle("참여 완료")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Submit

    private func submit() {
        // 초대 링크(dozyapp.kr/shared-calendar/join)로 열리면 initialCode 가 채워져 있다 (#90).
        viewModel.join(code: code, via: initialCode.isEmpty ? .code : .link) {
            withAnimation { joined = true }
        }
    }
}
