//
//  SharedCalendarCreateView.swift
//  Dozy AI
//

import SwiftUI

struct SharedCalendarCreateView: View {

    @ObservedObject var viewModel: SharedCalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var calendarName = ""
    @State private var creationResult: SharedCalendarCreationResult? = nil
    @FocusState private var isNameFocused: Bool

    private var isNameValid: Bool { !calendarName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            if let result = creationResult {
                successView(result: result)
            } else {
                createForm
            }
        }
    }

    // MARK: - Create Form

    private var createForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DozySpacing.xl) {
                    VStack(spacing: DozySpacing.sm) {
                        SharedCalendarHeaderIcon(symbol: "calendar.badge.plus")
                        Text("함께 쓸 캘린더 이름을 정해 주세요")
                            .font(DozyFont.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(DozyColor.Text.primary)
                        Text("만들고 나면 초대 코드로 최대 4명까지 함께할 수 있어요.")
                            .font(DozyFont.subheadline)
                            .foregroundStyle(DozyColor.Text.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DozySpacing.xl)

                    TextField("예: 우리 가족 캘린더", text: $calendarName)
                        .font(DozyFont.bodyEmphasized)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { if isNameValid { submit() } }
                        .padding(.horizontal, DozySpacing.md)
                        .frame(minHeight: 56)
                        .dozyThemedCardSurface(cornerRadius: DozyRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: DozyRadius.lg, style: .continuous)
                                .strokeBorder(isNameFocused ? DozyColor.Brand.primary : .clear, lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, DozySpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)

            Button {
                submit()
            } label: {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("만들기")
                }
            }
            .buttonStyle(SharedCalendarPrimaryButtonStyle())
            .disabled(!isNameValid || viewModel.isLoading)
            .padding(.horizontal, DozySpacing.lg)
            .padding(.bottom, DozySpacing.lg)
        }
        .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
        .navigationTitle("공유 캘린더 만들기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundStyle(DozyColor.Text.primary)
            }
        }
        .onAppear { isNameFocused = true }
    }

    // MARK: - Success (Invite Code Display)

    private func successView(result: SharedCalendarCreationResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DozySpacing.xl) {
                    VStack(spacing: DozySpacing.sm) {
                        SharedCalendarHeaderIcon(symbol: "checkmark")
                        Text("'\(calendarName.trimmingCharacters(in: .whitespaces))' 캘린더가 만들어졌어요")
                            .font(DozyFont.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(DozyColor.Text.primary)
                            .multilineTextAlignment(.center)
                        Text("아래 초대 코드를 함께할 사람에게 보내 주세요.")
                            .font(DozyFont.subheadline)
                            .foregroundStyle(DozyColor.Text.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DozySpacing.xl)

                    SharedInviteCodeCard(code: result.inviteCode, expiresAt: result.inviteCodeExpiresAt)
                }
                .padding(.horizontal, DozySpacing.lg)
            }

            Button("완료") { dismiss() }
                .buttonStyle(SharedCalendarSecondaryButtonStyle())
                .padding(.horizontal, DozySpacing.lg)
                .padding(.bottom, DozySpacing.lg)
        }
        .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
        .navigationTitle("공유 캘린더 만들기")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    // MARK: - Helpers

    private func submit() {
        guard isNameValid else { return }
        viewModel.create(name: calendarName) { result in
            withAnimation { creationResult = result }
        }
    }
}
