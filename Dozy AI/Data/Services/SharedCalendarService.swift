//
//  SharedCalendarService.swift
//  Dozy AI
//

import Foundation
import Combine
import Supabase
import OSLog

final class SharedCalendarService: SharedCalendarServiceProtocol {

    // MARK: - Create

    func create(name: String) -> AnyPublisher<SharedCalendarCreationResult, DozyError> {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return Fail(error: DozyError.sharedCalendarInvalidName).eraseToAnyPublisher()
        }
        return Future { promise in
            Task {
                do {
                    let res: RPCResponse = try await supabase
                        .rpc("create_shared_calendar", params: ["p_name": name])
                        .execute()
                        .value
                    if let err = res.error {
                        switch err {
                        case "invalid_name": promise(.failure(.sharedCalendarInvalidName))
                        default:             promise(.failure(.sharedCalendarCodeGenerationFailed))
                        }
                        return
                    }
                    guard let calendarID = res.calendarID,
                          let inviteCode = res.inviteCode,
                          let expiresAt  = res.inviteCodeExpiresAt else {
                        promise(.failure(.sharedCalendarCodeGenerationFailed)); return
                    }
                    promise(.success(SharedCalendarCreationResult(
                        calendarID: calendarID,
                        inviteCode: inviteCode,
                        inviteCodeExpiresAt: expiresAt
                    )))
                } catch {
                    Logger.sharedCalendar.error("create 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Join

    func join(inviteCode: String) -> AnyPublisher<SharedCalendarJoinResult, DozyError> {
        return Future { promise in
            Task {
                do {
                    let res: RPCResponse = try await supabase
                        .rpc("join_shared_calendar", params: ["p_invite_code": inviteCode.uppercased()])
                        .execute()
                        .value
                    if let err = res.error {
                        switch err {
                        case "invalid_code":   promise(.failure(.sharedCalendarInvalidCode))
                        case "expired_code":   promise(.failure(.sharedCalendarExpiredCode))
                        case "calendar_full":  promise(.failure(.sharedCalendarFull))
                        case "already_member": promise(.failure(.sharedCalendarAlreadyMember(calendarID: res.calendarID ?? "")))
                        default:               promise(.failure(.sharedCalendarCodeGenerationFailed))
                        }
                        return
                    }
                    promise(.success(SharedCalendarJoinResult(calendarID: res.calendarID ?? "")))
                } catch {
                    Logger.sharedCalendar.error("join 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Regenerate Invite Code

    func regenerateInviteCode(calendarID: String) -> AnyPublisher<SharedCalendarInviteCodeResult, DozyError> {
        return Future { promise in
            Task {
                do {
                    let res: RPCResponse = try await supabase
                        .rpc("regenerate_shared_calendar_invite_code",
                             params: ["p_calendar_id": calendarID])
                        .execute()
                        .value
                    if let err = res.error {
                        switch err {
                        case "not_owner": promise(.failure(.sharedCalendarNotOwner))
                        default:          promise(.failure(.sharedCalendarCodeGenerationFailed))
                        }
                        return
                    }
                    guard let code = res.inviteCode, let expiresAt = res.inviteCodeExpiresAt else {
                        promise(.failure(.sharedCalendarCodeGenerationFailed)); return
                    }
                    promise(.success(SharedCalendarInviteCodeResult(
                        inviteCode: code, inviteCodeExpiresAt: expiresAt)))
                } catch {
                    Logger.sharedCalendar.error("regenerateInviteCode 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Fetch My Calendars

    func fetchMyCalendars() -> AnyPublisher<[SharedCalendar], DozyError> {
        return Future { promise in
            Task {
                do {
                    let rows: [SharedCalendarRow] = try await supabase
                        .from("shared_calendars")
                        .select()
                        .execute()
                        .value
                    promise(.success(rows.map { $0.toDomain() }))
                } catch {
                    Logger.sharedCalendar.error("fetchMyCalendars 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Fetch Members

    func fetchMembers(calendarID: String) -> AnyPublisher<[SharedCalendarMember], DozyError> {
        return Future { promise in
            Task {
                do {
                    let rows: [SharedCalendarMemberRow] = try await supabase
                        .from("shared_calendar_members")
                        .select()
                        .eq("shared_calendar_id", value: calendarID)
                        .execute()
                        .value
                    promise(.success(rows.map { $0.toDomain() }))
                } catch {
                    Logger.sharedCalendar.error("fetchMembers 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Leave (RLS 정책이 auth.uid() = user_id로 필터링)

    func leave(calendarID: String) -> AnyPublisher<Void, DozyError> {
        return Future { promise in
            Task {
                do {
                    let userID = try await supabase.auth.user().id.uuidString
                    try await supabase
                        .from("shared_calendar_members")
                        .delete()
                        .eq("shared_calendar_id", value: calendarID)
                        .eq("user_id", value: userID)
                        .execute()
                    promise(.success(()))
                } catch {
                    Logger.sharedCalendar.error("leave 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Update Calendar Name

    func updateCalendarName(calendarID: String, name: String) -> AnyPublisher<Void, DozyError> {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return Fail(error: DozyError.sharedCalendarInvalidName).eraseToAnyPublisher()
        }
        return Future { promise in
            Task {
                do {
                    try await supabase
                        .from("shared_calendars")
                        .update(["name": trimmed])
                        .eq("id", value: calendarID)
                        .execute()
                    promise(.success(()))
                } catch {
                    Logger.sharedCalendar.error("updateCalendarName 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Update Nickname

    func updateNickname(calendarID: String, nickname: String) -> AnyPublisher<Void, DozyError> {
        return Future { promise in
            Task {
                do {
                    let userID = try await supabase.auth.user().id.uuidString
                    try await supabase
                        .from("shared_calendar_members")
                        .update(["nickname": nickname])
                        .eq("shared_calendar_id", value: calendarID)
                        .eq("user_id", value: userID)
                        .execute()
                    promise(.success(()))
                } catch {
                    Logger.sharedCalendar.error("updateNickname 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Delete (owner only, CASCADE)

    func delete(calendarID: String) -> AnyPublisher<Void, DozyError> {
        return Future { promise in
            Task {
                do {
                    try await supabase
                        .from("shared_calendars")
                        .delete()
                        .eq("id", value: calendarID)
                        .execute()
                    promise(.success(()))
                } catch {
                    Logger.sharedCalendar.error("delete 실패: \(error)")
                    promise(.failure(.unknown(underlying: error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Private DTOs

/// 모든 RPC 함수가 공유하는 통합 응답 DTO.
/// 성공: success=true + 함수별 필드
/// 실패: error="error_code" + 선택적 calendar_id
private struct RPCResponse: Decodable {
    let success: Bool?
    let error: String?
    let calendarID: String?
    let inviteCode: String?
    let inviteCodeExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case calendarID         = "calendar_id"
        case inviteCode         = "invite_code"
        case inviteCodeExpiresAt = "invite_code_expires_at"
    }
}

private struct SharedCalendarRow: Decodable {
    let id: String
    let name: String
    let inviteCode: String
    let inviteCodeExpiresAt: Date
    let createdBy: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
        case inviteCodeExpiresAt = "invite_code_expires_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    func toDomain() -> SharedCalendar {
        SharedCalendar(
            id: id, name: name,
            inviteCode: inviteCode,
            inviteCodeExpiresAt: inviteCodeExpiresAt,
            createdBy: createdBy, createdAt: createdAt
        )
    }
}

private struct SharedCalendarMemberRow: Decodable {
    let sharedCalendarID: String
    let userID: String
    let role: String
    let joinedAt: Date
    let nickname: String?

    enum CodingKeys: String, CodingKey {
        case sharedCalendarID = "shared_calendar_id"
        case userID = "user_id"
        case role
        case joinedAt = "joined_at"
        case nickname
    }

    func toDomain() -> SharedCalendarMember {
        SharedCalendarMember(
            sharedCalendarID: sharedCalendarID,
            userID: userID,
            role: SharedCalendarRole(rawValue: role) ?? .member,
            joinedAt: joinedAt,
            nickname: nickname
        )
    }
}

private extension Logger {
    static let sharedCalendar = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dozy", category: "SharedCalendar")
}
