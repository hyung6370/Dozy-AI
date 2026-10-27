//
//  MacCalendarSettingsViewModel.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 4/27/26.
//

import Foundation
import Combine
import EventKit

@MainActor
final class MacCalendarSettingsViewModel: ObservableObject {

    /// SwiftUI Toggle 이 직접 바인딩하는 상태값. CalendarSourceManager 와 동기화되며
    /// 사용자 토글 액션은 이 값 변화를 observe 해서 처리(권한 요청 등 사이드이펙트 분리).
    /// 커스텀 Binding(get:set:) 을 쓰면 비동기 권한 콜백 와중에 SwiftUI 토글 애니메이션이
    /// 끊기면서 macOS 에서 thumb 이 사라진 채 파란 막대만 남는 렌더링 버그가 발생한다.
    @Published var isAppleEnabled: Bool

    @Published var errorMessage: String?
    @Published private(set) var isRequestingAccess = false

    let sourceManager: CalendarSourceManager
    private let appleCalendarService: CalendarService

    private var cancellables = Set<AnyCancellable>()

    /// observer 내부에서 isAppleEnabled 를 되돌릴 때 무한 재진입을 막는 가드.
    private var isReverting = false

    init(sourceManager: CalendarSourceManager, appleCalendarService: CalendarService) {
        self.sourceManager = sourceManager
        self.appleCalendarService = appleCalendarService
        self.isAppleEnabled = sourceManager.isEnabled(.apple)

        $isAppleEnabled
            .dropFirst()                                 // 초기값 알림은 무시
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.handleToggle(newValue: newValue)
            }
            .store(in: &cancellables)
    }

    private func handleToggle(newValue: Bool) {
        if isReverting {
            isReverting = false
            return
        }

        if !newValue {
            sourceManager.disable(.apple)
            broadcastSourceChange()
            return
        }
        
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .authorized {
            sourceManager.enable(.apple)
            broadcastSourceChange()
            return
        }
        if status == .denied || status == .restricted {
            revertToOff()
            errorMessage = "캘린더 권한이 거부되었습니다..."
            return
        }

        isRequestingAccess = true
        appleCalendarService.requestAccess()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.isRequestingAccess = false
                    if case .failure = completion {
                        self.revertToOff()
                        self.errorMessage = "캘린더 권한이 거부되었습니다. 시스템 설정 > 개인정보 보호 및 보안 > 캘린더 에서 Dozy 를 허용해주세요."
                    }
                },
                receiveValue: { [weak self] granted in
                    guard let self else { return }
                    self.isRequestingAccess = false
                    if granted {
                        self.sourceManager.enable(.apple)
                        self.broadcastSourceChange()
                    } else {
                        self.revertToOff()
                        self.errorMessage = "캘린더 권한이 거부되었습니다. 시스템 설정 > 개인정보 보호 및 보안 > 캘린더 에서 Dozy 를 허용해주세요."
                    }
                }
            )
            .store(in: &cancellables)
    }

    /// 권한 거부 시 토글을 시각적으로 OFF 로 되돌린다. observer 재진입은 isReverting 으로 차단.
    private func revertToOff() {
        isReverting = true
        isAppleEnabled = false
    }

    /// 캘린더 소스 토글 직후 — Calendar/Today/MenuBar VM 들이 듣는 sync 알림을 그대로 재사용해
    /// 캐시 invalidate + 재로드를 트리거. (별도 알림을 정의해도 되지만 동작이 동일하므로 재사용.)
    private func broadcastSourceChange() {
        NotificationCenter.default.post(name: .dozyDataSyncCompleted, object: nil)
    }
}
