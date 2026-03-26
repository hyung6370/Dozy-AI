//
//  FetchRecentLogsUseCase.swift
//  Dozy AI
//
//  [Clean Architecture - UseCase]
//  최근 N일간의 WorkLog를 가져오는 비즈니스 로직을 캡슐화합니다.
//  트렌드 차트, 최근 기록 섹션 등에서 사용됩니다.

import Foundation
import Combine

final class FetchRecentLogsUseCase {

    private let repository: WorkLogRepositoryProtocol

    init(repository: WorkLogRepositoryProtocol) {
        self.repository = repository
    }

    /// 최근 N일간의 WorkLog 목록을 반환합니다 (기본 7일)
    func execute(days: Int = 7) -> AnyPublisher<[WorkLog], DozyError> {
        repository.fetchRecentLogs(days: days)
    }
}
