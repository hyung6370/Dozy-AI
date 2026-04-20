//
//  SharedCalendarViewModel.swift
//  Dozy AI
//

import Foundation
import Combine

@MainActor
final class SharedCalendarViewModel: ObservableObject {

    // MARK: - Published

    @Published var calendars: [SharedCalendar] = []
    @Published var membersMap: [String: [SharedCalendarMember]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var creationResult: SharedCalendarCreationResult? = nil

    // MARK: - Dependencies

    private let createUseCase: CreateSharedCalendarUseCase
    private let joinUseCase: JoinSharedCalendarUseCase
    private let leaveUseCase: LeaveSharedCalendarUseCase
    private let regenerateUseCase: RegenerateSharedCalendarInviteCodeUseCase
    private let updateNicknameUseCase: UpdateSharedCalendarNicknameUseCase
    private let service: SharedCalendarServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        createUseCase: CreateSharedCalendarUseCase,
        joinUseCase: JoinSharedCalendarUseCase,
        leaveUseCase: LeaveSharedCalendarUseCase,
        regenerateUseCase: RegenerateSharedCalendarInviteCodeUseCase,
        updateNicknameUseCase: UpdateSharedCalendarNicknameUseCase,
        service: SharedCalendarServiceProtocol
    ) {
        self.createUseCase = createUseCase
        self.joinUseCase = joinUseCase
        self.leaveUseCase = leaveUseCase
        self.regenerateUseCase = regenerateUseCase
        self.updateNicknameUseCase = updateNicknameUseCase
        self.service = service
    }

    // MARK: - Load

    func loadCalendars() {
        isLoading = true
        service.fetchMyCalendars()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] in
                    self?.isLoading = false
                    if case .failure(let error) = $0 { self?.errorMessage = error.localizedDescription }
                },
                receiveValue: { [weak self] calendars in
                    self?.calendars = calendars
                    for cal in calendars { self?.loadMembers(calendarID: cal.id) }
                }
            )
            .store(in: &cancellables)
    }

    func loadMembers(calendarID: String) {
        service.fetchMembers(calendarID: calendarID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] members in
                    self?.membersMap[calendarID] = members
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Create

    func create(name: String, completion: @escaping (SharedCalendarCreationResult) -> Void) {
        isLoading = true
        createUseCase.execute(name: name)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] in
                    self?.isLoading = false
                    if case .failure(let error) = $0 { self?.errorMessage = error.localizedDescription }
                },
                receiveValue: { [weak self] result in
                    self?.loadCalendars()
                    completion(result)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Join

    func join(code: String, completion: @escaping () -> Void) {
        isLoading = true
        joinUseCase.execute(inviteCode: code)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] in
                    self?.isLoading = false
                    if case .failure(let error) = $0 { self?.errorMessage = error.localizedDescription }
                },
                receiveValue: { [weak self] _ in
                    self?.loadCalendars()
                    completion()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Leave / Delete

    func leave(calendar: SharedCalendar, currentUserID: String, completion: @escaping () -> Void) {
        let isOwner = membersMap[calendar.id]?.first(where: { $0.userID == currentUserID })?.role == .owner
        isLoading = true
        leaveUseCase.execute(calendarID: calendar.id, isOwner: isOwner)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] in
                    self?.isLoading = false
                    if case .failure(let error) = $0 { self?.errorMessage = error.localizedDescription }
                },
                receiveValue: { [weak self] in
                    self?.calendars.removeAll { $0.id == calendar.id }
                    self?.membersMap.removeValue(forKey: calendar.id)
                    completion()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Update Calendar Name

    func updateCalendarName(calendarID: String, name: String, completion: @escaping () -> Void) {
        service.updateCalendarName(calendarID: calendarID, name: name)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] in
                    if case .failure(let error) = $0 { self?.errorMessage = error.localizedDescription }
                },
                receiveValue: { [weak self] in
                    if let idx = self?.calendars.firstIndex(where: { $0.id == calendarID }) {
                        let old = self!.calendars[idx]
                        self?.calendars[idx] = SharedCalendar(
                            id: old.id, name: name,
                            inviteCode: old.inviteCode,
                            inviteCodeExpiresAt: old.inviteCodeExpiresAt,
                            createdBy: old.createdBy, createdAt: old.createdAt
                        )
                    }
                    completion()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Update Nickname

    func updateNickname(calendarID: String, nickname: String, currentUserID: String, completion: @escaping () -> Void) {
        updateNicknameUseCase.execute(calendarID: calendarID, nickname: nickname)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] in
                    if case .failure(let error) = $0 { self?.errorMessage = error.localizedDescription }
                },
                receiveValue: { [weak self] in
                    // 로컬 membersMap 즉시 반영
                    if var members = self?.membersMap[calendarID],
                       let idx = members.firstIndex(where: { $0.userID == currentUserID }) {
                        members[idx].nickname = nickname
                        self?.membersMap[calendarID] = members
                    }
                    completion()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Regenerate Invite Code

    func regenerateCode(calendarID: String, completion: @escaping (String) -> Void) {
        regenerateUseCase.execute(calendarID: calendarID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] in
                    if case .failure(let error) = $0 { self?.errorMessage = error.localizedDescription }
                },
                receiveValue: { [weak self] result in
                    // Update local calendar invite code
                    if let idx = self?.calendars.firstIndex(where: { $0.id == calendarID }) {
                        let old = self!.calendars[idx]
                        self?.calendars[idx] = SharedCalendar(
                            id: old.id, name: old.name,
                            inviteCode: result.inviteCode,
                            inviteCodeExpiresAt: result.inviteCodeExpiresAt,
                            createdBy: old.createdBy, createdAt: old.createdAt
                        )
                    }
                    completion(result.inviteCode)
                }
            )
            .store(in: &cancellables)
    }
}
