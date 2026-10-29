//
//  SaveEventDisplaySettingsUseCase.swift
//  Dozy AI
//
//  외부 일정 표시 설정 저장 (#72 선행 리팩터링). Dozy 일정은 모델에 직접 저장하므로 UpdateDozyEventUseCase 를 쓴다.
//

import Foundation
import Combine

final class SaveEventDisplaySettingsUseCase {

    private let repository: EventDisplaySettingsRepositoryProtocol

    init(repository: EventDisplaySettingsRepositoryProtocol) {
        self.repository = repository
    }

    func execute(eventID: String, priority: Int, isPinned: Bool, category: String) -> AnyPublisher<Void, Never> {
        repository.save(eventID: eventID, priority: priority, isPinned: isPinned, category: category)
    }
}
