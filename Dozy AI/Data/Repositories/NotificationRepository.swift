//
//  NotificationRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import Foundation
import SwiftData
import Combine

final class NotificationRepository {
    
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
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
        Future { [modelContainer] promise in
            Task { @MainActor in
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
        Future { [modelContainer] promise in
            Task { @MainActor in
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
