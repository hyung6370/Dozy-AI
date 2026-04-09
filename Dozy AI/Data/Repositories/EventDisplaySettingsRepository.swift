//
//  EventDisplaySettingsRepository.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import Foundation
import SwiftData
import Combine
import Supabase

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
    
    // 설정 저장 (없으면 생성, 있으면 업데이트) + Supabase 즉시 동기화
    func save(eventID: String, priority: Int, isPinned: Bool, category: String = "일반") -> AnyPublisher<Void, Never> {
        Future { [modelContainer] promise in
            Task { @MainActor in
                let descriptor = FetchDescriptor<EventDisplaySettings>(
                    predicate: #Predicate { $0.eventID == eventID }
                )
                if let existing = try? modelContainer.mainContext.fetch(descriptor).first {
                    existing.priority = priority
                    existing.isPinned = isPinned
                    existing.category = category
                } else {
                    modelContainer.mainContext.insert(
                        EventDisplaySettings(eventID: eventID, priority: priority, isPinned: isPinned, category: category)
                    )
                }
                try? modelContainer.mainContext.save()
                promise(.success(()))

                // Supabase 즉시 업로드 (로컬 저장 완료 후 비동기)
                guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
                let row = EventDisplaySettingsUploadRow(
                    userID: userID,
                    eventID: eventID,
                    priority: priority,
                    isPinned: isPinned,
                    category: category,
                    updatedAt: Date()
                )
                try? await supabase.from("event_display_settings")
                    .upsert(row, onConflict: "user_id, event_id")
                    .execute()
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Supabase DTO

private struct EventDisplaySettingsUploadRow: Codable {
    let userID: String
    let eventID: String
    let priority: Int
    let isPinned: Bool
    let category: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case eventID = "event_id"
        case priority
        case isPinned = "is_pinned"
        case category
        case updatedAt = "updated_at"
    }
}
