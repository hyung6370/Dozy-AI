//
//  ActiveSharedCalendarStore.swift
//  Dozy AI
//
//  "기본 공유 캘린더" 1개를 UserDefaults에 저장/관리합니다.
//  - 캘린더 탭 / 홈 탭에서 이 ID의 공유 일정만 표시 (Phase 2에서 필터링 로직 연결)
//  - 일정 생성 시 기본 공유 캘린더 1개만 Picker에 노출 (Phase 3)
//

import Foundation
import Combine

@MainActor
final class ActiveSharedCalendarStore: ObservableObject {

    static let shared = ActiveSharedCalendarStore()

    @Published private(set) var activeCalendarID: String?

    private let key = "active_shared_calendar_id"

    private init() {
        self.activeCalendarID = UserDefaults.standard.string(forKey: key)
    }

    func setActive(_ id: String?) {
        if let id, !id.isEmpty {
            UserDefaults.standard.set(id, forKey: key)
            activeCalendarID = id
        } else {
            UserDefaults.standard.removeObject(forKey: key)
            activeCalendarID = nil
        }
    }

    func isActive(_ id: String) -> Bool {
        activeCalendarID == id
    }

    /// 해당 캘린더가 더 이상 존재하지 않는 경우 (탈퇴/삭제) 기본값 해제
    func clearIfMatches(_ id: String) {
        if activeCalendarID == id {
            setActive(nil)
        }
    }
}
