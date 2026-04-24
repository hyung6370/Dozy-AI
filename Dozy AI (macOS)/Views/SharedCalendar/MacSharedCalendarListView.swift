//
//  MacSharedCalendarListView.swift
//  Dozy AI (macOS)
//
//  M4.8b — 공유 캘린더 목록 시트. 생성 / 참여 메뉴, 각 행은 상세 시트로 이동.
//  iOS SharedCalendarListView 대비 편집 모드(순서 변경)와 활성 캘린더 토글은 유보.
//

import SwiftUI

struct MacSharedCalendarListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: MacAuthViewModel
    @StateObject private var viewModel: SharedCalendarViewModel

    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var selectedCalendar: SharedCalendar? = nil
    @State private var deletingCalendar: SharedCalendar? = nil

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

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.calendars.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.calendars.isEmpty {
                    emptyState
                } else {
                    calendarList
                }
            }
            .navigationTitle("공유 캘린더")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("새 공유 캘린더 만들기", systemImage: "plus.circle")
                        }
                        Button {
                            showJoinSheet = true
                        } label: {
                            Label("초대 코드로 참여", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Label("추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                MacSharedCalendarCreateView(viewModel: viewModel)
            }
            .sheet(isPresented: $showJoinSheet) {
                MacSharedCalendarJoinView(viewModel: viewModel)
            }
            .sheet(item: $selectedCalendar) { cal in
                MacSharedCalendarDetailView(
                    calendar: cal,
                    viewModel: viewModel,
                    currentUserID: authViewModel.currentUser?.id ?? ""
                )
            }
            .alert(
                "오류",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert(
                "공유 캘린더 나가기",
                isPresented: Binding(
                    get: { deletingCalendar != nil },
                    set: { if !$0 { deletingCalendar = nil } }
                )
            ) {
                Button("나가기", role: .destructive) {
                    if let cal = deletingCalendar,
                       let userID = authViewModel.currentUser?.id {
                        viewModel.leave(calendar: cal, currentUserID: userID) { }
                    }
                    deletingCalendar = nil
                }
                Button("취소", role: .cancel) { deletingCalendar = nil }
            } message: {
                Text("'\(deletingCalendar?.name ?? "")'에서 나가시겠습니까?\n소유자인 경우 캘린더 자체가 삭제됩니다.")
            }
            .onAppear { viewModel.loadCalendars() }
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 480)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("공유 캘린더가 없어요")
                .font(.headline)
            Text("파트너와 함께 쓸 캘린더를 만들거나\n초대 코드로 참여해 보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("만들기", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    showJoinSheet = true
                } label: {
                    Label("초대 코드 참여", systemImage: "person.badge.plus")
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var calendarList: some View {
        List {
            ForEach(viewModel.calendars) { cal in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.2.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cal.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(viewModel.membersMap[cal.id]?.count ?? 1)명 참여")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { selectedCalendar = cal }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deletingCalendar = cal
                    } label: {
                        Label("나가기", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .contextMenu {
                    Button {
                        selectedCalendar = cal
                    } label: {
                        Label("상세 보기", systemImage: "info.circle")
                    }
                    Button(role: .destructive) {
                        deletingCalendar = cal
                    } label: {
                        Label("나가기", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
}
