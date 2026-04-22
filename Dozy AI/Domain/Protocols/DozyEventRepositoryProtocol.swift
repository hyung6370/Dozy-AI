//
//  DozyEventRepositoryProtocol.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import Foundation
import Combine

protocol DozyEventRepositoryProtocol {
    func fetchEvents(from: Date, to: Date) -> AnyPublisher<[DozyEvent], DozyError>
    func fetchAllRecurring() -> AnyPublisher<[DozyEvent], DozyError>
    func save(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>
    func update(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>
    func delete(_ event: DozyEvent) -> AnyPublisher<Void, DozyError>

    /// Apple/Google 원본 이벤트를 Dozy 공유 캘린더로 미러링.
    /// 같은 (현재 사용자, externalSource, externalEventID) 조합이 이미 있으면 대상 공유 캘린더만 갱신한다.
    func mirrorExternalEvent(
        _ origin: CalendarEvent,
        to sharedCalendarID: String
    ) -> AnyPublisher<DozyEvent, DozyError>

    /// 현재 사용자가 소유한 외부 미러 스냅샷 전체를 반환.
    func fetchMyExternalMirrors() -> AnyPublisher<[DozyEvent], DozyError>

    /// 외부 원본과 대조 결과를 반영:
    /// - `updates`: 원본과 필드 차이가 있거나 복원된 스냅샷 (externalDeleted=false로 복원)
    /// - `deletedIDs`: 원본이 사라진 스냅샷 id 목록 (externalDeleted=true로 마킹)
    /// 모든 대상에 대해 externalLastSyncedAt을 now로 업데이트.
    func applyExternalMirrorReconcile(
        updates: [ExternalMirrorUpdate],
        deletedIDs: [String]
    ) -> AnyPublisher<Void, DozyError>

    /// 유예 기간이 지난 미러 스냅샷을 실제로 삭제. 로컬 + Supabase 모두.
    /// Supabase DELETE는 Realtime으로 파트너 기기에 전파된다.
    func deleteExternalMirrors(ids: [String]) -> AnyPublisher<Void, DozyError>
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
