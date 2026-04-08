//
//  EventDisplaySettingsRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import Foundation
import SwiftData
import Combine

final class EventDisplaySettingsRepository {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // 전체 설정 조회 (앱 시작 시 일괄 로드용)
    func fetchAll() -> AnyPublisher<[String: EventDisplaySettings], Never> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let descriptor = FetchDescriptor<EventDisplaySettings>()
                let all = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
                let dict = Dictionary(uniqueKeysWithValues: all.map { ($0.eventID, $0) })
                promise(.success(dict))
            }
        }
        .eraseToAnyPublisher()
    }

    // 여러 eventID에 대한 설정을 한 번에 조회
    func fetchAll(for eventIDs: [String]) -> AnyPublisher<[String: EventDisplaySettings], Never> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let descriptor = FetchDescriptor<EventDisplaySettings>()
                let all = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
                let dict = Dictionary(uniqueKeysWithValues: all
                    .filter { eventIDs.contains($0.eventID) }
                    .map { ($0.eventID, $0) }
                )
                promise(.success(dict))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 설정 저장 (없으면 생성, 있으면 업데이트)
    func save(eventID: String, priority: Int, isPinned: Bool) {
        Task { @MainActor in
            let descriptor = FetchDescriptor<EventDisplaySettings>(
                predicate: #Predicate { $0.eventID == eventID }
            )
            if let existing = try? modelContainer.mainContext.fetch(descriptor).first {
                existing.priority = priority
                existing.isPinned = isPinned
            } else {
                modelContainer.mainContext.insert(
                    EventDisplaySettings(eventID: eventID, priority: priority, isPinned: isPinned)
                )
            }
            try? modelContainer.mainContext.save()
        }
    }
}
