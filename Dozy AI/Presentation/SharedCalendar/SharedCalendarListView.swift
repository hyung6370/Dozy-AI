//
//  SharedCalendarListView.swift
//  Dozy AI
//

import SwiftUI
import Kingfisher

struct SharedCalendarListView: View {

    @StateObject private var viewModel: SharedCalendarViewModel
    @ObservedObject private var activeStore = ActiveSharedCalendarStore.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false

    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: SharedCalendarViewModel(
            createUseCase: container.createSharedCalendarUseCase,
            joinUseCase: container.joinSharedCalendarUseCase,
            leaveUseCase: container.leaveSharedCalendarUseCase,
            regenerateUseCase: container.regenerateSharedCalendarInviteCodeUseCase,
            updateNicknameUseCase: container.updateSharedCalendarNicknameUseCase,
            service: container.sharedCalendarService
        ))
    }

    @State private var editMode: EditMode = .inactive

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.calendars.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
            } else if viewModel.calendars.isEmpty {
                emptyState
                    .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
            } else {
                calendarList
            }
        }
        .navigationTitle("공유 캘린더")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.calendars.count > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    // 편집 아이콘 ↔ 편집 중엔 "완료" (카테고리 관리와 같은 패턴)
                    Button {
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    } label: {
                        if editMode == .active {
                            Text("완료").fontWeight(.semibold)
                        } else {
                            Image(symbol: "square.and.pencil")
                        }
                    }
                    .foregroundStyle(DozyColor.Text.primary)
                    .accessibilityLabel(editMode == .active ? "편집 완료" : "순서 편집")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("새 공유 캘린더 만들기", symbol: "calendar.badge.plus")
                    }
                    Button {
                        showJoinSheet = true
                    } label: {
                        Label("초대 코드로 참여", symbol: "person.badge.plus")
                    }
                } label: {
                    Image(symbol: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(DozyColor.Text.primary)
                }
                .accessibilityLabel("공유 캘린더 추가")
            }
        }
        .dozyBackButton()   // 시스템 뒤로가기 → btn_navi_back 에셋 (스와이프 백 유지 — 자체 toolbar(편집) 뒤에 둬야 가장 왼쪽)
        .sheet(isPresented: $showCreateSheet) {
            SharedCalendarCreateView(viewModel: viewModel)
        }
        .sheet(isPresented: $showJoinSheet) {
            SharedCalendarJoinView(viewModel: viewModel)
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear { viewModel.loadCalendars() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                showCreateSheet = false
                showJoinSheet = false
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DozySpacing.xl) {
            Spacer()
            SharedCalendarHeaderIcon(symbol: "person.2.fill", size: 88)
            VStack(spacing: DozySpacing.xs) {
                Text("함께 쓰는 캘린더를 만들어 보세요")
                    .font(DozyFont.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(DozyColor.Text.primary)
                Text("가족 · 연인 · 친구와 최대 4명까지\n일정을 함께 보고 관리할 수 있어요")
                    .font(DozyFont.subheadline)
                    .foregroundStyle(DozyColor.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: DozySpacing.sm) {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("새 공유 캘린더 만들기", symbol: "calendar.badge.plus")
                }
                .buttonStyle(SharedCalendarPrimaryButtonStyle())

                Button {
                    showJoinSheet = true
                } label: {
                    Label("초대 코드로 참여하기", symbol: "person.badge.plus")
                }
                .buttonStyle(SharedCalendarSecondaryButtonStyle())
            }
            .padding(.horizontal, DozySpacing.xxl)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Calendar List

    private var calendarList: some View {
        List {
            Section {
                ForEach(viewModel.calendars) { calendar in
                    NavigationLink {
                        SharedCalendarDetailView(
                            calendar: calendar,
                            viewModel: viewModel
                        )
                    } label: {
                        calendarRow(calendar)
                    }
                    .listRowBackground(DozyColor.Background.groupedRow)
                }
                .onMove { source, destination in
                    viewModel.moveCalendar(from: source, to: destination)
                }
            } footer: {
                Text("별표가 붙은 기본 캘린더의 일정이 캘린더 탭에 표시돼요.")
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
            }
        }
        // List 유지 (onMove 보존). themed shell bg 가 비치도록 투명 — 카테고리 관리와 같은 패턴.
        .environment(\.editMode, $editMode)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
    }

    private func calendarRow(_ calendar: SharedCalendar) -> some View {
        let members = viewModel.membersMap[calendar.id] ?? []
        let currentUserID = authViewModel.currentUser?.id ?? ""
        let isActive = activeStore.isActive(calendar.id)
        return HStack(spacing: DozySpacing.sm) {
            SharedCalendarCover(imageURL: calendar.publicImageURL, size: 52)
            VStack(alignment: .leading, spacing: DozySpacing.xxs) {
                HStack(spacing: DozySpacing.xxs) {
                    Text(calendar.name)
                        .font(DozyFont.bodyEmphasized)
                        .foregroundStyle(DozyColor.Text.primary)
                        .lineLimit(1)
                    if isActive {
                        Image(symbol: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DozyColor.Brand.primary)
                            .accessibilityLabel("기본 캘린더")
                    }
                }
                HStack(spacing: DozySpacing.xs) {
                    if !members.isEmpty {
                        SharedMemberAvatarStack(
                            items: members.map { .init(id: $0.userID, name: $0.displayName(currentUserID: currentUserID)) },
                            size: 22
                        )
                    }
                    Text("\(members.count)명 참여 중")
                        .font(DozyFont.caption)
                        .foregroundStyle(DozyColor.Text.secondary)
                }
            }
        }
        .padding(.vertical, DozySpacing.xxs)
    }
}
