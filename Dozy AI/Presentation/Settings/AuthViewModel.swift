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

    /// 회원가입 OTP 흐름 진행 상태. View 가 단계별 UI 분기에 사용.
    @Published var emailOTPStep: EmailOTPStep = .idle

    /// 클라이언트 측 코드 입력 마감 시각. View 가 TimelineView 로 카운트다운 렌더.
    /// Supabase 서버 측 OTP 유효시간(5분) 보다 짧게 두어 "다시 받기" 를 적극 유도 (3분).
    @Published var otpExpiresAt: Date?

    /// 비밀번호 재설정 OTP 흐름 진행 상태 — signup 흐름과 분리.
    @Published var passwordResetStep: EmailOTPStep = .idle

    /// 재설정 카운트다운 만료 시각.
    @Published var passwordResetExpiresAt: Date?

    enum EmailOTPStep: Equatable {
        case idle               // 회원가입 폼 진입 전
        case otpSent(String)    // OTP 발송 완료, 코드 입력 대기
        case verified(String)   // OTP 검증 완료, 비밀번호 입력 대기
    }

    /// OTP 검증까지만 마치고 비밀번호 set 전에 앱이 죽으면 partial 사용자가
    /// signed-in 상태로 남는다 — 다음 부팅 시 .initialSession 이 이 키를 보고 정리.
    static let signupInProgressKey = "signupInProgressEmail"

    /// 클라이언트 카운트다운 길이 (초). Supabase OTP_EXPIRY (5분) 보다 짧게.
    private static let otpClientTTL: TimeInterval = 180  // 3분

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
                    // mid-signup 정리: OTP 검증까지만 마치고 비밀번호 set 전에 앱이 죽으면
                    // partial 사용자가 signed-in 상태로 남는다 — 강제 sign out.
                    if let pendingEmail = UserDefaults.standard.string(forKey: Self.signupInProgressKey),
                       session.user.email?.lowercased() == pendingEmail {
                        UserDefaults.standard.removeObject(forKey: Self.signupInProgressKey)
                        try? await supabase.auth.signOut()
                        continue
                    }
                    let providerString = session.user.appMetadata["provider"]?.stringValue ?? ""
                    let provider: AuthProvider = {
                        switch providerString {
                        case "google": return .google
                        case "email":  return .email
                        default:       return .apple
                        }
                    }()
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

    // MARK: - Email / Password 로그인

    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        authService.signInWithEmail(email: email, password: password)
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
                    self?.requestNotificationPermissionIfNeeded()
                    self?.showCongratulationAnimation = true
                    self?.syncAfterLogin(userID: user.id)
                    self?.startSharedCalendarRealtime()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Email signup (OTP)

    /// Step 1: 이메일에 OTP 코드 전송. 성공 시 .otpSent 로 step 전환.
    func sendEmailOTP(email: String) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        authService.sendEmailOTP(email: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    self.emailOTPStep = .otpSent(normalized)
                    self.otpExpiresAt = Date().addingTimeInterval(Self.otpClientTTL)
                }
            )
            .store(in: &cancellables)
    }

    /// Step 2: OTP 코드 검증. 성공 시 .verified 로 step 전환 + signup-in-progress 플래그 set.
    func verifyEmailOTP(email: String, code: String) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        authService.verifyEmailOTP(email: email, code: code)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    self.emailOTPStep = .verified(normalized)
                    self.otpExpiresAt = nil
                    UserDefaults.standard.set(normalized, forKey: Self.signupInProgressKey)
                }
            )
            .store(in: &cancellables)
    }

    /// Step 3: 비밀번호 set + 가입 완료. 성공 시 currentUser 세팅 → 메인 진입.
    func completeEmailSignUp(password: String) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        authService.setPasswordForCurrentSession(password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    guard let self else { return }
                    UserDefaults.standard.removeObject(forKey: Self.signupInProgressKey)
                    self.emailOTPStep = .idle
                    self.otpExpiresAt = nil
                    self.currentUser = user
                    self.requestNotificationPermissionIfNeeded()
                    self.showCongratulationAnimation = true
                    self.syncAfterLogin(userID: user.id)
                    self.startSharedCalendarRealtime()
                }
            )
            .store(in: &cancellables)
    }

    /// 사용자가 가입 흐름을 도중에 취소 / 다른 모드로 전환할 때.
    func cancelEmailOTPFlow() {
        emailOTPStep = .idle
        otpExpiresAt = nil
        errorMessage = nil
        if UserDefaults.standard.string(forKey: Self.signupInProgressKey) != nil {
            UserDefaults.standard.removeObject(forKey: Self.signupInProgressKey)
            Task {
                try? await supabase.auth.signOut()
            }
        }
    }

    // MARK: - Password reset (OTP)

    /// Step 1: 재설정 OTP 발송.
    func sendPasswordResetOTP(email: String) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        authService.sendPasswordResetOTP(email: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    self.passwordResetStep = .otpSent(normalized)
                    self.passwordResetExpiresAt = Date().addingTimeInterval(Self.otpClientTTL)
                }
            )
            .store(in: &cancellables)
    }

    /// Step 2: 재설정 OTP 검증 — 성공 시 recovery 세션으로 sign-in.
    func verifyPasswordResetOTP(email: String, code: String) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        authService.verifyPasswordResetOTP(email: email, code: code)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    self.passwordResetStep = .verified(normalized)
                    self.passwordResetExpiresAt = nil
                }
            )
            .store(in: &cancellables)
    }

    /// Step 3: 새 비밀번호로 변경 + 자동 로그인. 이전 비밀번호와 같으면 거부.
    func completePasswordReset(password: String) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        authService.isSameAsCurrentPassword(password)
            .flatMap { [authService] same -> AnyPublisher<AuthUser, DozyError> in
                if same {
                    return Fail(error: .passwordSameAsCurrent).eraseToAnyPublisher()
                }
                return authService.setPasswordForCurrentSession(password)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] user in
                    guard let self else { return }
                    self.passwordResetStep = .idle
                    self.passwordResetExpiresAt = nil
                    self.currentUser = user
                    self.requestNotificationPermissionIfNeeded()
                    self.showCongratulationAnimation = true
                    self.syncAfterLogin(userID: user.id)
                    self.startSharedCalendarRealtime()
                }
            )
            .store(in: &cancellables)
    }

    /// 사용자가 비밀번호 찾기 흐름을 취소 / 로그인으로 돌아갈 때.
    func cancelPasswordResetFlow() {
        passwordResetStep = .idle
        passwordResetExpiresAt = nil
        errorMessage = nil
        if case .verified = passwordResetStep {
            Task { try? await supabase.auth.signOut() }
        }
    }

    func signUpWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        authService.signUpWithEmail(email: email, password: password)
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
                    guard let self else { return }
                    // 로컬 SwiftData 전체 삭제 — 다른 계정으로 로그인했을 때 이전 사용자의
                    // UserCategory(userID 컬럼 없음) / DozyEvent / WorkLog 가 잔존해서
                    // 카테고리 목록·통계가 섞이는 것 방지.
                    self.syncService.clearAllLocalData()
                    // currentUser 및 Keychain 정리는 authStateChanges .signedOut 이벤트에서도 처리되지만
                    // UX 즉시성을 위해 여기서도 명시적으로 초기화합니다.
                    self.currentUser = nil
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
