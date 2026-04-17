//
//  SharedCalendarServiceProtocol.swift
//  Dozy AI
//

import Foundation
import Combine

protocol SharedCalendarServiceProtocol {
    /// 공유 캘린더 생성 (RPC: create_shared_calendar). 생성자는 owner로 자동 등록.
    func create(name: String) -> AnyPublisher<SharedCalendarCreationResult, DozyError>

    /// 초대 코드로 참여 (RPC: join_shared_calendar). 2인 제한 + 만료 검증.
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
}
