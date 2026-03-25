//
//  DependencyContainer.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine

final class DependencyContainer: ObservableObject {
    
    // MARK: - Services
    lazy var calendarService: CalendarServiceProtocol = CalendarService()
    lazy var reminderService: ReminderServiceProtocol = ReminderService()
    lazy var workLogRepository: WorkLogRepositoryProtocol = WorkLogRepository()
}
