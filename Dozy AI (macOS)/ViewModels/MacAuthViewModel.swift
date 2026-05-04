//
//  MacAuthViewModel.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 4/23/26.
//

import Foundation
import Combine
import SwiftData
import Supabase
import OSLog

@MainActor
final class MacAuthViewModel: ObservableObject {
    
    enum State {
        case loading
        case signedOut
        case signedIn(AuthUser)
    }
    
    @Published var state: State = .loading
    @Published var errorMessage: String?
    @Published var isSigningIn = false
    /// 사용자 트리거 로그인 성공 직후 한 번 true. MacAppRootView 가 Lottie 오버레이로 노출.
    /// session 복원에는 세팅하지 않음 (앱 부팅 시마다 재생되면 안 됨).
    @Published var showCongratulationAnimation = false
    
    private let authService: AuthService
    private let modelContainer: ModelContainer
    private let syncService: SyncService
    private let sharedCalendarService: SharedCalendarServiceProtocol
    private let realtimeService: SharedCalendarRealtimeService
    private var cancellables = Set<AnyCancellable>()

    var currentUser: AuthUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    init(
        authService: AuthService,
        modelContainer: ModelContainer,
        sharedCalendarService: SharedCalendarServiceProtocol,
        realtimeService: SharedCalendarRealtimeService
    ) {
        self.authService = authService
        self.modelContainer = modelContainer
        self.syncService = SyncService(modelContext: modelContainer.mainContext)
        self.sharedCalendarService = sharedCalendarService
        self.realtimeService = realtimeService
    }

    // MARK: - Sign-in success + sync

    /// 로그인/세션 복원 성공 시 공통 처리 — 상태 전환 후 Supabase 동기화 트리거.
    private func completeSignIn(_ user: AuthUser) {
        state = .signedIn(user)
        syncAfterLogin(userID: user.id)
        startSharedCalendarRealtime()
    }

    /// 공유 캘린더 목록을 가져와 각각에 대해 Realtime 채널 구독 시작.
    /// 파트너가 INSERT 하는 일정에 대해 알림 카드를 생성하려면 이 구독이 필요함.
    private func startSharedCalendarRealtime() {
        sharedCalendarService.fetchMyCalendars()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.auth.warning("⚠️ 공유 캘린더 목록 조회 실패: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] calendars in
                    guard let self else { return }
                    for cal in calendars {
                        self.realtimeService.startWatching(calendarID: cal.id)
                    }
                    if !calendars.isEmpty {
                        Logger.auth.info("📡 공유 캘린더 Realtime 구독 시작 (\(calendars.count)개)")
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func syncAfterLogin(userID: String) {
        syncService.syncAll(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.sync.error("❌ syncAll 실패: \(error.localizedDescription)")
                    }
                },
                receiveValue: { _ in
                    Logger.sync.info("✅ syncAll 완료 → dozyDataSyncCompleted")
                    NotificationCenter.default.post(name: .dozyDataSyncCompleted, object: nil)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Session
    
    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            let providerString = session.user.appMetadata["provider"]?.stringValue ?? ""
            let provider: AuthProvider = {
                switch providerString {
                case "google": return .google
                case "email":  return .email
                default:       return .apple
                }
            }()
            let user = AuthUser(
                id: session.user.id.uuidString.lowercased(),
                email: session.user.email,
                displayName: nil,
                provider: provider
            )
            completeSignIn(user)
        } catch {
            state = .signedOut
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        
        authService.signInWithApple()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                }, receiveValue: { [weak self] user in
                    self?.state = .signedIn(user)
                    self?.showCongratulationAnimation = true
                    self?.startSharedCalendarRealtime()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil

        authService.signInWithGoogle()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.completeSignIn(user)
                    self?.showCongratulationAnimation = true
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Email / Password

    func signInWithEmail(email: String, password: String) {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil

        authService.signInWithEmail(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.completeSignIn(user)
                    self?.showCongratulationAnimation = true
                }
            )
            .store(in: &cancellables)
    }

    func signUpWithEmail(email: String, password: String) {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil

        authService.signUpWithEmail(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSigningIn = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.completeSignIn(user)
                    self?.showCongratulationAnimation = true
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Sign out

    func signOut() {
        authService.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    // 로컬 SwiftData 전체 삭제 — 다른 계정으로 로그인했을 때 이전 사용자의
                    // UserCategory(userID 컬럼 없음) / DozyEvent / WorkLog 가 잔존해서
                    // 카테고리 목록·통계가 섞이는 것 방지.
                    self.syncService.clearAllLocalData()
                    self.state = .signedOut
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 회원탈퇴

    func deleteAccount() {
        authService.deleteAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.state = .signedOut
                }
            )
            .store(in: &cancellables)
    }
}
