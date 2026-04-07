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
