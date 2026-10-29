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

    @State private var showLeaveAlert = false
    @State private var showEditSheet = false
    @State private var currentCode: String

    init(calendar: SharedCalendar, viewModel: SharedCalendarViewModel) {
        self.calendar = calendar
        self.viewModel = viewModel
        _currentCode = State(initialValue: calendar.inviteCode ?? "")
    }

    private var currentUserID: String { authViewModel.currentUser?.id ?? "" }
    private var members: [SharedCalendarMember] { viewModel.membersMap[calendar.id] ?? [] }
    private var isOwner: Bool { members.first(where: { $0.userID == currentUserID })?.role == .owner }

    private var currentCalendar: SharedCalendar {
        viewModel.calendars.first(where: { $0.id == calendar.id }) ?? calendar
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DozySpacing.xl) {
                heroCard
                if !currentCode.isEmpty {
                    inviteSection
                }
                membersSection
                leaveSection
            }
            .padding(.vertical, DozySpacing.lg)
        }
        .refreshable {
            viewModel.loadMembers(calendarID: calendar.id)
        }
        .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
        .navigationTitle(currentCalendar.name)
        .navigationBarTitleDisplayMode(.inline)
        .dozyBackButton()   // 시스템 뒤로가기 → btn_navi_back 에셋 (스와이프 백 유지)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(symbol: "pencil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(DozyColor.Text.primary)
                }
                .accessibilityLabel("캘린더 설정")
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            viewModel.loadMembers(calendarID: calendar.id)
        }) {
            SharedCalendarEditView(
                calendar: currentCalendar,
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
        .onAppear { viewModel.loadMembers(calendarID: calendar.id) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                showLeaveAlert = false
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

    // MARK: - Hero

    /// 대표 이미지 · 이름 · 멤버 묶음 · 기본 캘린더 토글
    private var heroCard: some View {
        let isActive = activeStore.isActive(calendar.id)
        return VStack(spacing: DozySpacing.md) {
            SharedCalendarCover(imageURL: currentCalendar.publicImageURL, size: 88, cornerRadius: DozyRadius.xl)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            VStack(spacing: DozySpacing.xs) {
                Text(currentCalendar.name)
                    .font(DozyFont.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(DozyColor.Text.primary)
                    .multilineTextAlignment(.center)
                HStack(spacing: DozySpacing.xs) {
                    if !members.isEmpty {
                        SharedMemberAvatarStack(
                            items: members.map { .init(id: $0.userID, name: $0.displayName(currentUserID: currentUserID)) },
                            size: 26
                        )
                    }
                    Text("\(members.count)명 참여 중")
                        .font(DozyFont.subheadline)
                        .foregroundStyle(DozyColor.Text.secondary)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeStore.setActive(isActive ? nil : calendar.id)
                }
            } label: {
                Label(isActive ? "기본 캘린더" : "기본 캘린더로 설정", symbol: isActive ? "star.fill" : "star")
                    .font(DozyFont.subheadlineEmphasized)
                    .padding(.horizontal, DozySpacing.md)
                    .padding(.vertical, DozySpacing.xs)
                    .foregroundStyle(isActive ? .white : DozyColor.Brand.primary)
                    .background(
                        isActive ? AnyShapeStyle(DozyColor.Brand.primary) : AnyShapeStyle(DozyColor.Brand.primary.opacity(0.12)),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint("기본으로 지정한 공유 캘린더의 일정이 캘린더 탭에 표시돼요.")

            Text("기본으로 지정한 공유 캘린더의 일정이 캘린더 탭에 표시돼요.")
                .font(DozyFont.caption)
                .foregroundStyle(DozyColor.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DozySpacing.xl)
        .padding(.horizontal, DozySpacing.md)
        .dozyThemedCardSurface(cornerRadius: DozyRadius.xl)
        .padding(.horizontal, DozySpacing.md)
    }

    // MARK: - Invite

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: DozySpacing.sm) {
            sectionHeader("초대하기")
            SharedInviteCodeCard(
                code: currentCode,
                expiresAt: currentCalendar.inviteCodeExpiresAt,
                onRegenerate: isOwner ? {
                    viewModel.regenerateCode(calendarID: calendar.id) { newCode in
                        currentCode = newCode
                    }
                } : nil
            )
            Text("코드를 받은 사람이 '초대 코드로 참여하기'에 입력하면 함께 쓸 수 있어요.")
                .font(DozyFont.caption)
                .foregroundStyle(DozyColor.Text.tertiary)
                .padding(.horizontal, DozySpacing.md)
        }
        .padding(.horizontal, DozySpacing.md)
    }

    // MARK: - Members

    private var membersSection: some View {
        DozyListSection(header: "멤버") {
            if members.isEmpty {
                HStack(spacing: DozySpacing.sm) {
                    ProgressView()
                    Text("멤버 정보를 불러오는 중...")
                        .font(DozyFont.subheadline)
                        .foregroundStyle(DozyColor.Text.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DozySpacing.md)
            } else {
                ForEach(members, id: \.userID) { member in
                    memberRow(member)
                }
            }
        }
    }

    private func memberRow(_ member: SharedCalendarMember) -> some View {
        let isMe = member.userID == currentUserID
        let name = member.displayName(currentUserID: currentUserID)
        return HStack(spacing: DozySpacing.sm) {
            SharedMemberAvatar(name: name, seed: member.userID, size: 40, isOwner: member.isOwner)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DozySpacing.xxs) {
                    Text(name)
                        .font(DozyFont.bodyEmphasized)
                        .foregroundStyle(DozyColor.Text.primary)
                    if isMe, member.nickname?.isEmpty == false {
                        Text("나")
                            .font(DozyFont.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(DozyColor.Brand.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DozyColor.Brand.primary.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(member.joinedAt.formatted(.dateTime.year().month().day())) 참여")
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
            }
            Spacer(minLength: DozySpacing.xs)
            Text(member.isOwner ? "소유자" : "멤버")
                .font(DozyFont.captionEmphasized)
                .foregroundStyle(member.isOwner ? DozyColor.Brand.primary : DozyColor.Text.secondary)
                .padding(.horizontal, DozySpacing.xs)
                .padding(.vertical, DozySpacing.xxs)
                .background(
                    member.isOwner ? DozyColor.Brand.primary.opacity(0.12) : DozyColor.Background.grouped,
                    in: Capsule()
                )
        }
        .padding(.horizontal, DozySpacing.md)
        .padding(.vertical, DozySpacing.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Leave

    private var leaveSection: some View {
        DozyListSection(footer: isOwner
                        ? "삭제하면 캘린더와 모든 공유 일정이 멤버 모두에게서 사라져요."
                        : "나가도 이미 공유된 일정은 다른 멤버에게 남아 있어요.") {
            Button {
                showLeaveAlert = true
            } label: {
                DozyListRow(
                    title: isOwner ? "공유 캘린더 삭제" : "공유 캘린더 나가기",
                    titleColor: DozyColor.State.danger,
                    icon: {
                        DozyTintedIcon(
                            systemName: isOwner ? "trash" : "rectangle.portrait.and.arrow.right",
                            tint: DozyColor.State.danger
                        )
                    }
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(DozyFont.title3)
            .fontWeight(.bold)
            .foregroundStyle(DozyColor.Text.secondary)
            .padding(.horizontal, DozySpacing.md)
    }
}
