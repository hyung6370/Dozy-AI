//
//  NotificationRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import Foundation
import SwiftData
import Combine
import Supabase

final class NotificationRepository {

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// 로그인 여부 가드 — 미로그인 상태에선 fetch 류 메서드가 빈 결과를 반환하도록.
    /// clearAllLocalData 가 race / 실패해서 잔여 NotificationRecord 가 남아 있어도
    /// UI 에 노출되지 않게 하는 방어층.
    @MainActor
    private func isSignedIn() async -> Bool {
        (try? await supabase.auth.session.user.id) != nil
    }
    
    // 기록 저장 (알림 예약 시 호출)
    func save(_ record: NotificationRecord) {
        Task { @MainActor in
            modelContainer.mainContext.insert(record)
            try? modelContainer.mainContext.save()
        }
    }
    
    // 전체 알림 기록 조회 (예정 포함)
    func fetchDelivered() -> AnyPublisher<[NotificationRecord], Never> {
        Future { [modelContainer, weak self] promise in
            Task { @MainActor in
                guard await (self?.isSignedIn() ?? false) else {
                    promise(.success([]))
                    return
                }
                let descriptor = FetchDescriptor<NotificationRecord>(
                    sortBy: [SortDescriptor(\.deliveryDate, order: .reverse)]
                )
                let records = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
                promise(.success(records))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 전체 읽음 처리
    func markAllAsRead() {
        Task { @MainActor in
            let descriptor = FetchDescriptor<NotificationRecord>(
                predicate: #Predicate<NotificationRecord> { !$0.isRead }
            )
            let records = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
            records.forEach { $0.isRead = true }
            try? modelContainer.mainContext.save()
        }
    }
    
    // 단건 삭제
    func delete(_ record: NotificationRecord) {
        Task { @MainActor in
            modelContainer.mainContext.delete(record)
            try? modelContainer.mainContext.save()
        }
    }
    
    // 읽지 않은 알림 존재 여부
    func hasUnread() -> AnyPublisher<Bool, Never> {
        Future { [modelContainer, weak self] promise in
            Task { @MainActor in
                guard await (self?.isSignedIn() ?? false) else {
                    promise(.success(false))
                    return
                }
                let descriptor = FetchDescriptor<NotificationRecord>(
                    predicate: #Predicate<NotificationRecord> { !$0.isRead }
                )
                let count = (try? modelContainer.mainContext.fetchCount(descriptor)) ?? 0
                promise(.success(count > 0))
            }
        }
        .eraseToAnyPublisher()
    }
}
