//
//  AuthViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import Foundation
import Combine
import SwiftData
import OSLog
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: AuthUser? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showCongratulationAnimation = false
    @Published var pendingInviteCode: String? = nil

    private let authService: AuthService
    private let syncService: SyncService
    private let realtimeService: SharedCalendarRealtimeService
    private let sharedCalendarService: SharedCalendarServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    /// Keychain에 displayName을 저장할 때 사용하는 키.
    /// Supabase SDK는 토큰만 관리하고 displayName은 세션에 포함되지 않으므로
    /// 별도로 Keychain에 보관합니다.
    private static let displayNameKey = "auth.displayName"

    /// 앱 재시작 시 자동 동기화를 쓰로틀링하는 쿨다운 (1시간).
    /// 명시적 로그인은 항상 동기화하고, .initialSession 복원 시에만 쓰로틀을 적용합니다.
    private static let syncCooldown: TimeInterval = 3600

    private var isSyncThrottled: Bool {
        guard let lastSync = UserDefaults.standard.object(forKey: SyncService.lastSyncTimestampKey) as? Date else {
            return false // 동기화 이력 없음 → 즉시 동기화
        }
        return Date().timeIntervalSince(lastSync) < Self.syncCooldown
    }

    init(
        modelContext: ModelContext,
        authService: AuthService,
        sharedCalendarService: SharedCalendarServiceProtocol,
        realtimeService: SharedCalendarRealtimeService
    ) {
        self.authService = authService
        self.sharedCalendarService = sharedCalendarService
        self.syncService = SyncService(modelContext: modelContext)
        self.realtimeService = realtimeService
    }

    var isLoggedIn: Bool { currentUser != nil }

    // MARK: - 재설치 감지

    /// UserDefaults 플래그가 없으면 새 설치(또는 재설치)로 판단해 Keychain 세션을 초기화합니다.
    /// 삭제 시 UserDefaults는 지워지지만 Keychain은 유지되므로,
    /// 이 메서드를 startAuthListener() 전에 await 해서 호출해야 합니다.
    func clearSessionIfReinstalled() async {
        let key = "app.hasLaunchedBefore"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? await supabase.auth.signOut()
        KeychainService.delete(forKey: Self.displayNameKey)
        Logger.auth.info("🔄 재설치 감지 → Keychain 세션 초기화 완료")
    }

    // MARK: - Auth State Listener

    /// 앱 시작 시 한 번 호출합니다.
    /// supabase.auth.authStateChanges 스트림을 구독해:
    /// - .initialSession : Keychain에 저장된 세션으로 자동 로그인 (토큰 만료 시 SDK가 자동 갱신)
    /// - .tokenRefreshed : 액세스 토큰 갱신 완료 로그
    /// - .signedOut      : 세션 만료 또는 명시적 로그아웃 → 사용자 상태 초기화
    func startAuthListener() {
        Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .initialSession:
                    guard let session else { return }
                    let providerString = session.user.appMetadata["provider"]?.stringValue ?? ""
                    let provider: AuthProvider = providerString == "google" ? .google : .apple
                    self.currentUser = AuthUser(
                        id: session.user.id.uuidString.lowercased(),
                        email: session.user.email,
                        displayName: KeychainService.load(forKey: Self.displayNameKey),
                        provider: provider
                    )
                    self.requestNotificationPermissionIfNeeded()
                    if self.isSyncThrottled {
                        Logger.auth.info("⏩ 1시간 이내 동기화 이력 있음 — 자동 동기화 건너뜀")
                    } else {
                        self.syncAfterLogin(userID: session.user.id.uuidString.lowercased())
                    }
                    // Realtime 구독 + 초기 fetch는 throttle과 무관하게 항상 실행
                    // (syncAfterLogin이 건너뛰어도 파트너 이벤트는 동기화되어야 함)
                    self.startSharedCalendarRealtime()

                case .tokenRefreshed:
                    Logger.auth.info("🔑 액세스 토큰 자동 갱신 완료")

                case .signedOut:
                    self.realtimeService.stopAll()
                    self.currentUser = nil
                    KeychainService.delete(forKey: Self.displayNameKey)

                default:
                    break
                }
            }
        }
    }

    // MARK: - Apple 로그인

    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        authService.signInWithApple()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    if let name = user.displayName {
                        KeychainService.save(name, forKey: Self.displayNameKey)
                    }
                    self?.requestNotificationPermissionIfNeeded()
                    self?.showCongratulationAnimation = true
                    self?.syncAfterLogin(userID: user.id)
                    self?.startSharedCalendarRealtime()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Google 로그인

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        authService.signInWithGoogle()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    if let name = user.displayName {
                        KeychainService.save(name, forKey: Self.displayNameKey)
                    }
                    self?.requestNotificationPermissionIfNeeded()
                    self?.showCongratulationAnimation = true
                    self?.syncAfterLogin(userID: user.id)
                    self?.startSharedCalendarRealtime()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - 로그아웃

    func signOut() {
        authService.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] in
                    // currentUser 및 Keychain 정리는 authStateChanges .signedOut 이벤트에서도 처리되지만
                    // UX 즉시성을 위해 여기서도 명시적으로 초기화합니다.
                    self?.currentUser = nil
                    KeychainService.delete(forKey: Self.displayNameKey)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 회원탈퇴
    func deleteAccount() {
        isLoading = true
        errorMessage = nil
        authService.deleteAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    guard let self else { return }
                    // 로컬 데이터 전체 삭제
                    self.syncService.clearAllLocalData()
                    // Keychain 정리
                    KeychainService.delete(forKey: Self.displayNameKey)
                    // 상태 초기화 → UI가 비로그인 상태로 전환
                    self.currentUser = nil
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Private

    private func requestNotificationPermissionIfNeeded() {
        let notificationService = NotificationService()
        notificationService.requestAuthorization()
            .sink { _ in }
            .store(in: &cancellables)
    }

    private func syncAfterLogin(userID: String) {
        Logger.auth.info("🔄 syncAfterLogin 시작 userID=\(userID)")
        syncService.syncAll(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.auth.error("❌ syncAll 실패: \(error.localizedDescription)")
                    }
                },
                receiveValue: { _ in
                    Logger.auth.info("✅ syncAll 완료 → dozyDataSyncCompleted 전송")
                    NotificationCenter.default.post(name: .dozyDataSyncCompleted, object: nil)
                }
            )
            .store(in: &cancellables)
    }

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
}
