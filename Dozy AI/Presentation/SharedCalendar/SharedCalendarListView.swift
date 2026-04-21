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
    @Environment(\.colorScheme) private var colorScheme
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

    var body: some View {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.calendars.count > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
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
                    Image(colorScheme == .dark ? "Dark-Plus" : "Light-Plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
        }
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
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("공유 캘린더가 없어요")
                    .font(.headline)
                Text("파트너와 일정을 함께 관리해보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button {
                    showCreateSheet = true
                } label: {
                    Text("새 공유 캘린더 만들기")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    showJoinSheet = true
                } label: {
                    Text("초대 코드로 참여하기")
                        .font(.subheadline).fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Calendar List

    private var calendarList: some View {
        List {
            ForEach(viewModel.calendars) { calendar in
                NavigationLink {
                    SharedCalendarDetailView(
                        calendar: calendar,
                        viewModel: viewModel
                    )
                } label: {
                    calendarRow(calendar)
                }
            }
            .onMove { source, destination in
                viewModel.moveCalendar(from: source, to: destination)
            }
        }
    }

    private func calendarRow(_ calendar: SharedCalendar) -> some View {
        let members = viewModel.membersMap[calendar.id] ?? []
        let memberCount = members.count
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                if let url = calendar.publicImageURL {
                    KFImage(url)
                        .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 88, height: 88)))
                        .cacheOriginalImage()
                        .fade(duration: 0.15)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "calendar.badge.person.crop")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(calendar.name)
                        .font(.subheadline).fontWeight(.medium)
                    if activeStore.isActive(calendar.id) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text("\(memberCount)명 참여 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
