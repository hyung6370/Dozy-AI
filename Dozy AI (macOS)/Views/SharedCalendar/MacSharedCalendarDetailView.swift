//
//  MacSharedCalendarDetailView.swift
//  Dozy AI (macOS)
//
//  M4.8b — 공유 캘린더 상세 시트. 이름 수정 / 멤버 목록 / 내 닉네임 수정 /
//  초대 코드 복사·재생성 / 나가기.
//  iOS 대비 이미지 업로드, 파트너 이미지 표시는 유보.
//

import SwiftUI

struct MacSharedCalendarDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let calendar: SharedCalendar
    @ObservedObject var viewModel: SharedCalendarViewModel
    let currentUserID: String

    @State private var editableName: String = ""
    @State private var editableNickname: String = ""
    @State private var showLeaveAlert = false
    @State private var copied = false

    private var members: [SharedCalendarMember] {
        viewModel.membersMap[calendar.id] ?? []
    }

    private var me: SharedCalendarMember? {
        members.first { $0.userID == currentUserID }
    }

    private var isOwner: Bool { me?.role == .owner }

    private var currentCalendar: SharedCalendar {
        viewModel.calendars.first { $0.id == calendar.id } ?? calendar
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                inviteCodeSection
                membersSection
                nicknameSection
                leaveSection
            }
            .formStyle(.grouped)
            .navigationTitle("공유 캘린더 상세")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .alert(
                isOwner ? "공유 캘린더 삭제" : "공유 캘린더 나가기",
                isPresented: $showLeaveAlert
            ) {
                Button(isOwner ? "삭제" : "나가기", role: .destructive) {
                    viewModel.leave(calendar: currentCalendar, currentUserID: currentUserID) {
                        dismiss()
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text(isOwner
                     ? "소유자로서 나가면 캘린더 자체가 삭제되고 모든 파트너의 접근이 끊깁니다."
                     : "이 공유 캘린더에서 나가시겠습니까?")
            }
            .onAppear {
                editableName = currentCalendar.name
                editableNickname = me?.nickname ?? ""
                viewModel.loadMembers(calendarID: calendar.id)
            }
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 520)
    }

    // MARK: - Name

    private var nameSection: some View {
        Section {
            HStack {
                TextField("캘린더 이름", text: $editableName)
                    .disabled(!isOwner)
                if isOwner && editableName != currentCalendar.name &&
                   !editableName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("저장") {
                        viewModel.updateCalendarName(
                            calendarID: calendar.id,
                            name: editableName.trimmingCharacters(in: .whitespaces)
                        ) { }
                    }
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            Text("이름")
        } footer: {
            if !isOwner {
                Text("소유자만 이름을 변경할 수 있습니다.")
            }
        }
    }

    // MARK: - Invite Code

    private var inviteCodeSection: some View {
        Section {
            HStack(spacing: 10) {
                Text(currentCalendar.inviteCode ?? "-")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    copyCode()
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(currentCalendar.inviteCode == nil)

                if isOwner {
                    Button {
                        viewModel.regenerateCode(calendarID: calendar.id) { _ in }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .help("초대 코드 재생성")
                }
            }
            if let expires = currentCalendar.inviteCodeExpiresAt {
                Text("만료: \(expires.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("초대 코드")
        } footer: {
            Text(isOwner
                 ? "코드를 파트너에게 공유하세요. 재생성 시 이전 코드는 즉시 무효화됩니다."
                 : "초대 코드는 복사해서 다른 사람에게 공유할 수 있습니다.")
        }
    }

    // MARK: - Members

    private var membersSection: some View {
        Section {
            if members.isEmpty {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("멤버 불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(members, id: \.userID) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(member.role == .owner ? Color.blue.opacity(0.15) : Color.purple.opacity(0.12))
                                .frame(width: 30, height: 30)
                            Image(systemName: member.role == .owner ? "crown.fill" : "person.fill")
                                .font(.caption)
                                .foregroundStyle(member.role == .owner ? .blue : .purple)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.nickname?.isEmpty == false ? member.nickname! : "멤버")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(member.role == .owner ? "소유자" : "파트너")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if member.userID == currentUserID {
                            Spacer()
                            Text("나")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }
        } header: {
            Text("멤버")
        }
    }

    // MARK: - Nickname

    private var nicknameSection: some View {
        Section {
            HStack {
                TextField("내 닉네임 (선택)", text: $editableNickname)
                if editableNickname != (me?.nickname ?? "") {
                    Button("저장") {
                        viewModel.updateNickname(
                            calendarID: calendar.id,
                            nickname: editableNickname.trimmingCharacters(in: .whitespaces),
                            currentUserID: currentUserID
                        ) { }
                    }
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            Text("내 닉네임")
        } footer: {
            Text("이 캘린더에서 파트너에게 표시되는 내 별명입니다.")
        }
    }

    // MARK: - Leave

    private var leaveSection: some View {
        Section {
            Button {
                showLeaveAlert = true
            } label: {
                HStack {
                    Image(systemName: isOwner ? "trash.fill" : "rectangle.portrait.and.arrow.right")
                    Text(isOwner ? "공유 캘린더 삭제" : "나가기")
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Helpers

    private func copyCode() {
        guard let code = currentCalendar.inviteCode else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
