//
//  DozyEventRepositoryProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

protocol DozyEventRepositoryProtocol {
    func fetchEvents(from: Date, to: Date) async throws(DozyError) -> [DozyEvent]
    func fetchAllRecurring() async throws(DozyError) -> [DozyEvent]
    func save(_ event: DozyEvent) async throws(DozyError)
    func update(_ event: DozyEvent) async throws(DozyError)
    func delete(_ event: DozyEvent) async throws(DozyError)

    /// Apple/Google 원본 이벤트를 Dozy 공유 캘린더로 미러링.
    /// 같은 (현재 사용자, externalSource, externalEventID) 조합이 이미 있으면 대상 공유 캘린더만 갱신한다.
    func mirrorExternalEvent(
        _ origin: CalendarEvent,
        to sharedCalendarID: String
    ) async throws(DozyError) -> DozyEvent

    /// 현재 사용자가 소유한 외부 미러 스냅샷 전체를 반환.
    func fetchMyExternalMirrors() async throws(DozyError) -> [DozyEvent]

    /// 외부 원본과 대조 결과를 반영:
    /// - `updates`: 원본과 필드 차이가 있거나 복원된 스냅샷 (externalDeleted=false로 복원)
    /// - `deletedIDs`: 원본이 사라진 스냅샷 id 목록 (externalDeleted=true로 마킹)
    /// 모든 대상에 대해 externalLastSyncedAt을 now로 업데이트.
    func applyExternalMirrorReconcile(
        updates: [ExternalMirrorUpdate],
        deletedIDs: [String]
    ) async throws(DozyError)

    /// 유예 기간이 지난 미러 스냅샷을 실제로 삭제. 로컬 + Supabase 모두.
    /// Supabase DELETE는 Realtime으로 파트너 기기에 전파된다.
    func deleteExternalMirrors(ids: [String]) async throws(DozyError)
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)

extension DozyEventRepositoryProtocol {
    func fetchEvents(from: Date, to: Date) -> AnyPublisher<[DozyEvent], DozyError> {
        .bridge { () async throws(DozyError) -> [DozyEvent] in try await self.fetchEvents(from: from, to: to) }
    }

    func fetchAllRecurring() -> AnyPublisher<[DozyEvent], DozyError> {
        .bridge { () async throws(DozyError) -> [DozyEvent] in try await self.fetchAllRecurring() }
    }

    func save(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.save(event) }
    }

    func update(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.update(event) }
    }

    func delete(_ event: DozyEvent) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.delete(event) }
    }

    func mirrorExternalEvent(_ origin: CalendarEvent, to sharedCalendarID: String) -> AnyPublisher<DozyEvent, DozyError> {
        .bridge { () async throws(DozyError) -> DozyEvent in try await self.mirrorExternalEvent(origin, to: sharedCalendarID) }
    }

    func fetchMyExternalMirrors() -> AnyPublisher<[DozyEvent], DozyError> {
        .bridge { () async throws(DozyError) -> [DozyEvent] in try await self.fetchMyExternalMirrors() }
    }

    func applyExternalMirrorReconcile(updates: [ExternalMirrorUpdate], deletedIDs: [String]) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.applyExternalMirrorReconcile(updates: updates, deletedIDs: deletedIDs) }
    }

    func deleteExternalMirrors(ids: [String]) -> AnyPublisher<Void, DozyError> {
        .bridge { () async throws(DozyError) in try await self.deleteExternalMirrors(ids: ids) }
    }
}

/// Phase D reconcile 시 원본과 달라진 필드들을 전달하는 값 타입.
struct ExternalMirrorUpdate {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let colorHex: String
}
