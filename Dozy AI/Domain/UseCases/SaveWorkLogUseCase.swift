//
//  SaveWorkLogUseCase.swift
//  Dozy AI
//
//  [Clean Architecture - UseCase]
//  오늘의 WorkLog를 생성하거나 업데이트하는 비즈니스 로직을 캡슐화합니다.
//  - 이벤트·할 일 데이터로 WorkLog 생성/업데이트
//  - 메모 추가 — 오늘 WorkLog 가 없으면 만든다 (#137). 일정 로딩이 실패해도 메모는 쓸 수 있어야 한다.
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
        repository.fetchOrCreateLog(for: Date())
            .flatMap { [repository] log -> AnyPublisher<WorkLog, DozyError> in
                log.populate(with: events)
                log.populate(with: tasks)
                return repository.save(log)
                    .map { log }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    // MARK: - 오늘 WorkLog

    /// 오늘 WorkLog 를 가져오고, 없으면 만든다 (#137). 홈이 일정 로딩 결과를 기다리지 않고 메모를 보여 줄 때 쓴다.
    func todayLog() -> AnyPublisher<WorkLog, DozyError> {
        repository.fetchOrCreateLog(for: Date())
    }

    // MARK: - 메모 추가

    /// 오늘 WorkLog 에 메모를 추가하고 저장한 뒤 그 WorkLog 를 돌려준다.
    /// - 오늘 WorkLog 가 없으면 만든다 — 화면이 들고 있던 WorkLog 가 없거나 어제 것이어도 오늘에 붙는다.
    /// - 저장에 실패하면 붙였던 메모를 되돌린다. 화면에 저장 안 된 메모가 남거나, 다시 시도할 때 두 번 붙지 않게.
    func addMemo(_ text: String) -> AnyPublisher<WorkLog, DozyError> {
        repository.fetchOrCreateLog(for: Date())
            .flatMap { [repository] log -> AnyPublisher<WorkLog, DozyError> in
                log.addMemo(text)
                let index = log.memos.count - 1
                return repository.save(log)
                    .map { log }
                    .catch { error -> AnyPublisher<WorkLog, DozyError> in
                        if log.memos.indices.contains(index), log.memos[index] == text {
                            log.deleteMemo(at: index)
                        }
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// 메모를 수정하고 저장합니다
    func updateMemo(at index: Int, text: String, in log: WorkLog) -> AnyPublisher<Void, DozyError> {
        log.updateMemo(at: index, text: text)
        return repository.save(log)
    }

    /// 메모를 삭제하고 저장합니다
    func deleteMemo(at index: Int, in log: WorkLog) -> AnyPublisher<Void, DozyError> {
        log.deleteMemo(at: index)
        return repository.save(log)
    }
}
