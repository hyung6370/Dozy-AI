//
//  WorkLogRepositoryProtocol.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/24/26.
//

import Foundation
import Combine

protocol WorkLogRepositoryProtocol {
    // 특정 날짜의 WorkLog를 가져온다 (없으면 nil)
    func fetchLog(for date: Date) -> AnyPublisher<WorkLog?, DozyError>

    // 특정 날짜의 WorkLog 를 가져오고, 없으면 만들어 저장한 뒤 돌려준다 (#137)
    // 조회와 생성을 한 번에 처리해야 동시에 불려도 같은 날 WorkLog 가 둘 생기지 않는다.
    func fetchOrCreateLog(for date: Date) -> AnyPublisher<WorkLog, DozyError>
    
    // 최근 N일간의 WorkLog 목록을 가져온다
    func fetchRecentLogs(days: Int) -> AnyPublisher<[WorkLog], DozyError>
    
    // WorkLog를 저장한다 (삽입 또는 업데이트)
    func save(_ log: WorkLog) -> AnyPublisher<Void, DozyError>
    
    // WorkLog를 삭제한다
    func delete(_ log: WorkLog) -> AnyPublisher<Void, DozyError>
}
