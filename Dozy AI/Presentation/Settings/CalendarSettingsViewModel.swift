//
//  CalendarSettingsViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import Combine
import UIKit
import EventKit

@MainActor
final class CalendarSettingsViewModel: ObservableObject {

    @Published var errorMessage: String?
    @Published var showAppleCalendarPermissionAlert = false // Apple 캘린더 권한이 이미 거부된 상태에서 토글을 켰을 때 표시하는 안내 얼럿

    let sourceManager: CalendarSourceManager
    let googleSignInService: GoogleSignInService
    let naverSignInService: NaverSignInService

    private var cancellables = Set<AnyCancellable>()
    private let eventStore = EKEventStore() // 권한 요청 세션 유지용. EKEventStore는 요청이 끝날 때까지 강한 참조 필요
    /// 시스템 권한 얼럿을 이미 요청한 적이 있는지. 앱 삭제 시 TCC 상태와 함께 초기화되므로 일관성 유지.
    private static let didRequestAppleAccessKey = "dozy_apple_calendar_access_requested"
    /// "설정으로 이동"을 눌러 앱을 떠난 상태 - 복귀 시 권한 재확인용.
    /// 설정에서 권한을 바꾸면 iOS 가 앱을 재시작시키는 경우가 있어 메모리가 아닌
    /// UserDefaults 에 남긴다 — 재실행 후 화면 재진입(init) 시에도 확인 가능.
    private static let awaitingSettingsReturnKey = "dozy_apple_calendar_awaiting_settings_return"

    init(
        sourceManager: CalendarSourceManager,
        googleSignInService: GoogleSignInService,
        naverSignInService: NaverSignInService
    ) {
        self.sourceManager       = sourceManager
        self.googleSignInService = googleSignInService
        self.naverSignInService  = naverSignInService

        // 각 서비스 변경 시 View 갱신
        googleSignInService.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        naverSignInService.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // sourceManager.enabledSources 변화도 View 에 forward — UI 가 sourceManager
        // 기준으로 "연결됨" 분기하므로 enable/disable 시 즉시 갱신.
        sourceManager.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // 권한 변경으로 앱이 재시작된 경우 scenePhase 복귀 감지가 못 돌기 때문에,
        // 화면 재진입 시에도 "설정 다녀온 뒤 권한 허용" 케이스를 확인해 토글을 켠다.
        recheckAppleAccessAfterSettingsReturn()
    }

    // MARK: - Computed
    var isGoogleSignedIn: Bool { googleSignInService.isSignedIn }
    var googleUserEmail: String? { googleSignInService.userEmail }

    var isNaverSignedIn: Bool { naverSignInService.isSignedIn }
    var naverUserEmail: String? { naverSignInService.userEmail }

    // MARK: - Google
    func connectGoogle() {
        guard let vc = UIApplication.shared.topViewController else { return }
        googleSignInService.signIn(presenting: vc)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.sourceManager.enable(.google)
                }
            )
            .store(in: &cancellables)
    }

    func disconnectGoogle() {
        googleSignInService.signOut()
        sourceManager.disable(.google)
    }

    // MARK: - Naver
    func connectNaver() {
        naverSignInService.signIn()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] in
                    self?.sourceManager.enable(.naver)
                }
            )
            .store(in: &cancellables)
    }

    func disconnectNaver() {
        naverSignInService.signOut()
        sourceManager.disable(.naver)
    }

    // MARK: - Apple
    func toggleApple() {
        // 끄는 방향은 권한과 무관 - 비활성화
        guard !sourceManager.isEnabled(.apple) else {
            sourceManager.disable(.apple)
            return
        }

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            sourceManager.enable(.apple)

        case .notDetermined:
            // 최초 1회 - 여기서만 시스템 권한 얼럿이 뜬다.
            // 주의: 일부 iOS/시뮬레이터에서 거부 후에도 status 가 .notDetermined 로
            // 남는 경우가 있어, 요청 이력을 직접 기록해 "재요청이 얼럿 없이 즉시
            // 거부되는" 케이스를 실질적 denied 로 구분한다.
            let alreadyRequested = UserDefaults.standard.bool(forKey: Self.didRequestAppleAccessKey)
            eventStore.requestFullAccessToEvents { granted, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    UserDefaults.standard.set(true, forKey: Self.didRequestAppleAccessKey)
                    if granted {
                        self.sourceManager.enable(.apple)
                    } else if alreadyRequested {
                        // 이미 한 번 물었는데 또 즉시 거부 → 시스템 얼럿은 더 안 뜬다.
                        // 설정 이동 안내로 전환.
                        self.showAppleCalendarPermissionAlert = true
                    }
                    // 첫 거부는 방금 본인이 선택한 직후라 얼럿으로 되묻지 않는다.
                }
            }

        default:
            // .denied / .restricted / .writeOnly - 시스템 얼럿은 앱 설치당 1회만 표시되므로 다시 띄울 수 없다. 설정 앱으로 안내
            showAppleCalendarPermissionAlert = true
        }
    }

    // 설정 앱의 Dozy 항목으로 이동. 사용자가 캘린더 권한을 직접 켤 수 있다.
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UserDefaults.standard.set(true, forKey: Self.awaitingSettingsReturnKey)
        UIApplication.shared.open(url)
    }

    // 설정에서 돌아온 시점(scenePhase .active) 또는 앱 재시작 후 화면 재진입(init)에
    // 권한이 켜졌으면 토글 자동 활성화. 플래그는 1회성 — 확인 후 즉시 소비한다.
    func recheckAppleAccessAfterSettingsReturn() {
        guard UserDefaults.standard.bool(forKey: Self.awaitingSettingsReturnKey) else { return }
        UserDefaults.standard.removeObject(forKey: Self.awaitingSettingsReturnKey)
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            sourceManager.enable(.apple)
        }
    }
}
