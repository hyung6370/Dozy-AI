//
//  SaveWorkLogUseCase.swift
//  Dozy AI
//
//  [Clean Architecture - UseCase]
//  오늘의 WorkLog를 생성하거나 업데이트하는 비즈니스 로직을 캡슐화합니다.
//  - 이벤트·할 일 데이터로 WorkLog 생성/업데이트
//  - 메모 추가
//  ViewModel은 Repository를 직접 참조하지 않고 이 UseCase를 사용합니다.

import Foundation
import Combine

final class SaveWorkLogUseCase {

    private let repository: WorkLogRepositoryProtocol

    init(repository: WorkLogRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - 오늘 WorkLog 생성 또는 업데이트

    /// 이벤트·할 일로 오늘 WorkLog를 생성하거나 업데이트하고 반환합니다
    func execute(events: [CalendarEvent], tasks: [TaskItem]) -> AnyPublisher<WorkLog, DozyError> {
        repository.fetchLog(for: Date())
            .flatMap { [repository] existingLog -> AnyPublisher<WorkLog, DozyError> in
                let log = existingLog ?? WorkLog(date: Date())
                log.populate(with: events)
                log.populate(with: tasks)
                return repository.save(log)
                    .map { log }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 메모 추가

    /// 오늘 WorkLog에 메모를 추가하고 저장합니다
    func addMemo(_ text: String, to log: WorkLog) -> AnyPublisher<Void, DozyError> {
        log.addMemo(text)
        return repository.save(log)
    }
}
