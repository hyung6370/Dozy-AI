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
    
    /// 공유 일정 알림 카드 저장 — 같은 일정 카드가 이미 있으면 건너뛴다 (#95).
    /// Realtime INSERT · 푸시 수신 · 푸시 탭 · 앱 활성화 때 전달된 알림 수거가 같은 일정을 여러 번 넘길 수 있다.
    /// - Returns: 새로 만들었으면 true
    @MainActor
    @discardableResult
    func saveSharedIfNeeded(_ push: SharedEventPush, deliveredAt: Date = Date()) -> Bool {
        let context = modelContainer.mainContext
        let eventID = push.eventID
        let descriptor = FetchDescriptor<NotificationRecord>(
            predicate: #Predicate<NotificationRecord> { $0.eventID == eventID && $0.kind == "shared" }
        )
        if let count = try? context.fetchCount(descriptor), count > 0 { return false }
        context.insert(NotificationRecord(
            eventID: push.eventID,
            eventTitle: push.title,
            body: push.cardBody,
            deliveryDate: deliveredAt,
            eventStartDate: push.startDate ?? deliveredAt,
            kind: "shared",
            senderName: push.senderName
        ))
        try? context.save()
        return true
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
            guard !records.isEmpty else { return }
            records.forEach { $0.isRead = true }
            try? modelContainer.mainContext.save()
            // HomeViewModel 이 이 알림을 구독해 hasNotification 배지를 즉시 끈다.
            // 안 쏘면 사용자가 알림 화면을 보고 나와도 종 아이콘이 "on" 상태로 남음.
            NotificationCenter.default.post(name: .dozyNotificationsChanged, object: nil)
        }
    }

    // 단건 삭제
    func delete(_ record: NotificationRecord) {
        Task { @MainActor in
            modelContainer.mainContext.delete(record)
            try? modelContainer.mainContext.save()
            NotificationCenter.default.post(name: .dozyNotificationsChanged, object: nil)
        }
    }
    
    // 읽지 않은 알림 존재 여부.
    // ⚠️ deliveryDate <= now 조건 필수 — 일정 생성 시 예약된 미래 알림은 record 가 미리 저장되는데
    // (isRead=false 로 시작), 이걸 그대로 unread 로 세면 알림 발생 전부터 종 아이콘이 "on" 으로
    // 표시되는 버그가 생긴다. 실제로 도착한 알림만 카운트.
    func hasUnread() -> AnyPublisher<Bool, Never> {
        Future { [modelContainer, weak self] promise in
            Task { @MainActor in
                guard await (self?.isSignedIn() ?? false) else {
                    promise(.success(false))
                    return
                }
                let now = Date()
                let descriptor = FetchDescriptor<NotificationRecord>(
                    predicate: #Predicate<NotificationRecord> {
                        !$0.isRead && $0.deliveryDate <= now
                    }
                )
                let count = (try? modelContainer.mainContext.fetchCount(descriptor)) ?? 0
                promise(.success(count > 0))
            }
        }
        .eraseToAnyPublisher()
    }
}
