//
//  SharedCalendarServiceProtocol.swift
//  Dozy AI
//

import Foundation
import Combine

protocol SharedCalendarServiceProtocol {
    /// 공유 캘린더 생성 (RPC: create_shared_calendar). 생성자는 owner로 자동 등록.
    func create(name: String) -> AnyPublisher<SharedCalendarCreationResult, DozyError>

    /// 초대 코드로 참여 (RPC: join_shared_calendar). 최대 4인 제한 + 만료 검증.
    func join(inviteCode: String) -> AnyPublisher<SharedCalendarJoinResult, DozyError>

    /// 초대 코드 재발급 (RPC: regenerate_shared_calendar_invite_code). owner만 가능.
    func regenerateInviteCode(calendarID: String) -> AnyPublisher<SharedCalendarInviteCodeResult, DozyError>

    /// 내가 속한 공유 캘린더 목록 (RLS가 member 기준으로 필터링)
    func fetchMyCalendars() -> AnyPublisher<[SharedCalendar], DozyError>

    /// 특정 캘린더의 멤버 목록
    func fetchMembers(calendarID: String) -> AnyPublisher<[SharedCalendarMember], DozyError>

    /// 캘린더에서 나가기 (본인 member row 삭제)
    func leave(calendarID: String) -> AnyPublisher<Void, DozyError>

    /// 캘린더 삭제 (owner만, CASCADE)
    func delete(calendarID: String) -> AnyPublisher<Void, DozyError>

    /// 내 닉네임 업데이트 (본인 row만 수정 가능)
    func updateNickname(calendarID: String, nickname: String) -> AnyPublisher<Void, DozyError>

    /// 캘린더 이름 업데이트 (owner만 가능, RLS 적용)
    func updateCalendarName(calendarID: String, name: String) -> AnyPublisher<Void, DozyError>

    /// 캘린더 대표 이미지 업로드 (owner 전용). 기존 이미지가 있으면 교체 후 예전 파일 삭제.
    /// - Parameter jpegData: 512×512 JPEG로 리사이즈/압축된 데이터
    /// - Returns: 저장된 storage 경로 (shared_calendars.image_path 값)
    func uploadCalendarImage(calendarID: String, jpegData: Data, previousPath: String?) -> AnyPublisher<String, DozyError>

    /// 캘린더 대표 이미지 삭제 (owner 전용). image_path도 null로 업데이트.
    func removeCalendarImage(calendarID: String, path: String) -> AnyPublisher<Void, DozyError>
}
