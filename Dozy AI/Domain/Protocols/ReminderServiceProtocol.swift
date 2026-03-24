//
//  ReminderServiceProtocol.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine

protocol ReminderServiceProtocol {
    // 틀정 날짜에 완료된 미리알림을 가져온다
    func fetchCompletedReminders(for date: Date) -> AnyPublisher<[TaskItem], DozyError>
    
    // 미완료 미리알림을 가져온다 (다음 할 일 추천용)
    func fetchPendingReminders() -> AnyPublisher<[TaskItem], DozyError>
    
    // 미리알림 접근 권한을 요청한다
    func requestAccess() -> AnyPublisher<Bool, DozyError>
}
