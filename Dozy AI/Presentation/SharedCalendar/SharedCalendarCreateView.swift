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
    @State private var copied = false
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
            Form {
                Section {
                    TextField("예: 우리 가족 캘린더", text: $calendarName)
                        .focused($isNameFocused)
                        .onSubmit { if isNameValid { submit() } }
                } header: {
                    Text("캘린더 이름")
                } footer: {
                    Text("함께 사용할 캘린더 이름을 입력하세요. 최대 4명까지 참여 가능합니다.")
                }
            }
            .scrollDisabled(true)

            Spacer()

            Button {
                submit()
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("만들기")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    isNameValid && !viewModel.isLoading ? Color.accentColor : Color(.systemGray4),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!isNameValid || viewModel.isLoading)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationTitle("공유 캘린더 만들기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
        }
        .onAppear { isNameFocused = true }
    }

    // MARK: - Success (Invite Code Display)

    private func successView(result: SharedCalendarCreationResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("캘린더가 만들어졌어요!")
                            .font(.title3).fontWeight(.bold)
                        Text("아래 초대 코드를 함께할 사람에게 공유하세요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    codeCard(result: result)

                    Text("코드 유효 기간: \(result.inviteCodeExpiresAt.formatted(.dateTime.month().day().hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                ShareLink(
                    item: shareText(code: result.inviteCode),
                    subject: Text("Dozy AI 공유 캘린더 초대")
                ) {
                    Label("공유하기", systemImage: "square.and.arrow.up")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button("완료") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationTitle(calendarName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("완료") { dismiss() }
            }
        }
    }

    private func codeCard(result: SharedCalendarCreationResult) -> some View {
        VStack(spacing: 16) {
            Text("초대 코드")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(result.inviteCode)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .tracking(8)
                .foregroundStyle(Color.accentColor)

            Button {
                UIPasteboard.general.string = result.inviteCode
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Label(copied ? "복사됨" : "코드 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline)
                    .foregroundStyle(copied ? .green : .accentColor)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: copied)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func submit() {
        guard isNameValid else { return }
        viewModel.create(name: calendarName) { result in
            withAnimation { creationResult = result }
        }
    }

    private func shareText(code: String) -> String {
        "Dozy AI 공유 캘린더에 초대됐어요! 📅\n코드: \(code)\n\n앱에서 '초대 코드로 참여하기'를 눌러 입력하세요."
    }
}
