//
//  SharedCalendarDetailView.swift
//  Dozy AI
//

import SwiftUI

struct SharedCalendarDetailView: View {

    let calendar: SharedCalendar
    @ObservedObject var viewModel: SharedCalendarViewModel
    @ObservedObject private var activeStore = ActiveSharedCalendarStore.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var showLeaveAlert = false
    @State private var showNicknameAlert = false
    @State private var showEditSheet = false
    @State private var nicknameText = ""
    @State private var copied = false
    @State private var currentCode: String

    init(calendar: SharedCalendar, viewModel: SharedCalendarViewModel) {
        self.calendar = calendar
        self.viewModel = viewModel
        _currentCode = State(initialValue: calendar.inviteCode ?? "")
    }

    private var currentUserID: String { authViewModel.currentUser?.id ?? "" }
    private var members: [SharedCalendarMember] { viewModel.membersMap[calendar.id] ?? [] }
    private var isOwner: Bool { members.first(where: { $0.userID == currentUserID })?.role == .owner }
    private var isCodeExpired: Bool {
        guard let exp = calendar.inviteCodeExpiresAt else { return false }
        return exp < Date()
    }

    var body: some View {
        List {
            defaultCalendarSection
            membersSection
            if !currentCode.isEmpty {
                inviteCodeSection
            }
            leaveSection
        }
        .refreshable {
            viewModel.loadMembers(calendarID: calendar.id)
        }
        .navigationTitle(calendar.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(colorScheme == .dark ? "Dark-Peoples" : "Light-Peoples")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            viewModel.loadMembers(calendarID: calendar.id)
        }) {
            SharedCalendarEditView(
                calendar: calendar,
                isOwner: isOwner,
                currentUserID: currentUserID,
                viewModel: viewModel
            )
        }
        .alert(
            isOwner ? "캘린더를 삭제할까요?" : "공유 캘린더에서 나갈까요?",
            isPresented: $showLeaveAlert
        ) {
            Button(isOwner ? "삭제" : "나가기", role: .destructive) {
                viewModel.leave(calendar: calendar, currentUserID: currentUserID) {
                    dismiss()
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text(isOwner
                 ? "캘린더와 모든 공유 일정이 파트너에게도 삭제됩니다."
                 : "공유 일정은 유지되지만 더 이상 함께 관리할 수 없어요.")
        }
        .alert("닉네임 설정", isPresented: $showNicknameAlert) {
            TextField("닉네임 (최대 20자)", text: $nicknameText)
            Button("저장") {
                let trimmed = nicknameText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                viewModel.updateNickname(
                    calendarID: calendar.id,
                    nickname: String(trimmed.prefix(20)),
                    currentUserID: currentUserID
                ) { }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("공유 캘린더에서 표시될 내 이름을 설정하세요.")
        }
        .onAppear { viewModel.loadMembers(calendarID: calendar.id) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                showLeaveAlert = false
                showNicknameAlert = false
                showEditSheet = false
            }
        }
        .onReceive(viewModel.$calendars) { updated in
            if let fresh = updated.first(where: { $0.id == calendar.id }),
               let code = fresh.inviteCode {
                currentCode = code
            }
        }
    }

    // MARK: - Default Calendar Toggle

    private var defaultCalendarSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { activeStore.isActive(calendar.id) },
                set: { newVal in
                    activeStore.setActive(newVal ? calendar.id : nil)
                }
            )) {
                Label {
                    Text("기본 캘린더로 설정")
                } icon: {
                    Image(systemName: activeStore.isActive(calendar.id) ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
            }
        } footer: {
            Text("기본으로 지정한 공유 캘린더의 일정만 캘린더 탭에 표시됩니다.")
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        Section("멤버") {
            ForEach(members, id: \.userID) { member in
                memberRow(member)
            }
            if members.isEmpty {
                Text("멤버 정보를 불러오는 중...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func memberRow(_ member: SharedCalendarMember) -> some View {
        let isMe = member.userID == currentUserID
        let displayName = member.nickname ?? (isMe ? "나" : "파트너")
        let roleLabel = member.role == .owner ? "소유자" : "멤버"

        return HStack(spacing: 12) {
            if member.role == .owner {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .frame(width: 24)
            } else {
                Image(colorScheme == .dark ? "Dark-User" : "Light-User")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName).font(.subheadline)
                if member.nickname != nil {
                    Text(isMe ? "나" : "파트너")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(roleLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(UIColor.systemGray6), in: Capsule())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Invite Code Section

    private var inviteCodeSection: some View {
        Section {
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Text(currentCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(isCodeExpired ? Color(.systemGray3) : Color.accentColor)
                    Spacer()
                }

                if isCodeExpired {
                    Label("코드가 만료됐어요", systemImage: "clock.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = currentCode
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label {
                            Text(copied ? "복사됨" : "복사")
                        } icon: {
                            if copied {
                                Image(systemName: "checkmark")
                            } else {
                                Image(colorScheme == .dark ? "Dark-Copy" : "Light-Copy")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(copied ? .green : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: copied)

                    ShareLink(
                        item: shareText,
                        subject: Text("Dozy AI 공유 캘린더 초대")
                    ) {
                        Label {
                            Text("공유")
                        } icon: {
                            Image(colorScheme == .dark ? "Dark-Share" : "Light-Share")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)

            if isOwner {
                Button {
                    viewModel.regenerateCode(calendarID: calendar.id) { newCode in
                        currentCode = newCode
                    }
                } label: {
                    Label {
                        Text("새 코드 발급")
                    } icon: {
                        Image(colorScheme == .dark ? "Dark-Refresh" : "Light-Refresh")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    .foregroundStyle(.primary)
                }
            }
        } header: {
            Text("초대 코드")
        } footer: {
            if let exp = calendar.inviteCodeExpiresAt {
                Text("만료: \(exp.formatted(.dateTime.month().day().hour().minute()))")
            }
        }
    }

    // MARK: - Leave Section

    private var leaveSection: some View {
        Section {
            Button(role: .destructive) {
                showLeaveAlert = true
            } label: {
                Label {
                    Text(isOwner ? "공유 캘린더 삭제" : "공유 캘린더 나가기")
                } icon: {
                    if isOwner {
                        Image(colorScheme == .dark ? "Dark-Trash" : "Light-Trash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    } else {
                        Image(colorScheme == .dark ? "Dark-Exit" : "Light-Exit")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
            }
        }
    }

    // MARK: - Share Text

    private var shareText: String {
        String(localized: "Dozy AI 공유 캘린더에 초대됐어요! 📅\n코드: \(currentCode)\n\n앱에서 '초대 코드로 참여하기'를 눌러 입력하세요.")
    }
}
