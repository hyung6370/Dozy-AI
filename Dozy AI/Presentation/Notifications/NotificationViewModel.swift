//
//  NotificationViewModel.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import Foundation
import Combine

@MainActor
final class NotificationViewModel: ObservableObject {
    
    @Published var records: [NotificationRecord] = []
    @Published var hasUnread: Bool = false
    
    private let repository: NotificationRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: NotificationRepository) {
        self.repository = repository

        // 사용자가 알림 화면을 열어둔 상태에서 partner 가 일정을 공유하면
        // SharedCalendarRealtimeService 가 NotificationRecord 를 저장하고
        // .dozyNotificationsChanged 를 post — 그 시점에 자동으로 리스트
        // 갱신해야 새 카드가 즉시 노출된다.
        NotificationCenter.default.publisher(for: .dozyNotificationsChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadRecords()
                self?.refreshUnreadState()
            }
            .store(in: &cancellables)
    }
    
    func onAppear() {
        loadRecords()
        repository.markAllAsRead()
        hasUnread = false
    }
    
    func delete(_ record: NotificationRecord) {
        repository.delete(record)
        records.removeAll { $0.id == record.id }
    }
    
    func refreshUnreadState() {
        repository.hasUnread()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.hasUnread = value }
            .store(in: &cancellables)
    }
    
    private func loadRecords() {
        repository.fetchDelivered()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] records in self?.records = records }
            .store(in: &cancellables)
    }
}
