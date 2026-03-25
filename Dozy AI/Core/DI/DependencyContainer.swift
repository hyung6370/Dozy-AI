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
    
    // Phase 1: 캘린더 + 리마인더 + 저장소
    lazy var calendarService: CalendarServiceProtocol = CalendarService()
    lazy var reminderService: ReminderServiceProtocol = ReminderService()
    lazy var workLogRepository: WorkLogRepositoryProtocol = WorkLogRepository()
    
    // Phase 2: AI 요약 서비스
    lazy var aiService: AIServiceProtocol = AIService()
}
