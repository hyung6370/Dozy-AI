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

    /// calendarID → 파트너 닉네임 캐시. 파트너 이벤트 표시 시 사용.
    @Published private(set) var partnerNicknameByCalendarID: [String: String] = [:]

    private let key = "active_shared_calendar_id"

    private init() {
        self.activeCalendarID = UserDefaults.standard.string(forKey: key)
    }

    /// 특정 공유 캘린더의 파트너 닉네임 캐시 업데이트. 닉네임이 없으면 "파트너" 기본값.
    func updatePartnerNickname(_ nickname: String?, for calendarID: String) {
        let trimmed = nickname?.trimmingCharacters(in: .whitespaces) ?? ""
        partnerNicknameByCalendarID[calendarID] = trimmed.isEmpty ? nil : trimmed
    }

    /// 특정 캘린더의 파트너 표시 이름. 닉네임이 있으면 닉네임, 없으면 "파트너".
    func partnerDisplayName(for calendarID: String) -> String {
        partnerNicknameByCalendarID[calendarID] ?? "파트너"
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

    /// 로드된 공유 캘린더 목록을 기준으로 활성 ID를 자동 정리.
    /// - 탈퇴/삭제로 orphan이 된 활성 ID는 제거
    /// - 활성 미지정 상태이고 목록에 캘린더가 있으면 첫 번째를 자동 지정 (대부분의 사용자는 1개만 사용)
    func reconcile(with calendars: [SharedCalendar]) {
        if let activeID = activeCalendarID, !calendars.contains(where: { $0.id == activeID }) {
            setActive(nil)
        }
        if activeCalendarID == nil, let first = calendars.first {
            setActive(first.id)
        }
    }
}
