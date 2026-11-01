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

final class EventDisplaySettingsRepository: EventDisplaySettingsRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private var context: ModelContext { modelContainer.mainContext }

    // 전체 설정 조회 (앱 시작 시 일괄 로드용)
    func fetchAll() async -> [String: EventDisplaySettings] {
        let all = (try? context.fetch(FetchDescriptor<EventDisplaySettings>())) ?? []
        return Dictionary(uniqueKeysWithValues: all.map { ($0.eventID, $0) })
    }

    // 여러 eventID에 대한 설정을 한 번에 조회
    func fetchAll(for eventIDs: [String]) async -> [String: EventDisplaySettings] {
        let all = (try? context.fetch(FetchDescriptor<EventDisplaySettings>())) ?? []
        return Dictionary(uniqueKeysWithValues: all
            .filter { eventIDs.contains($0.eventID) }
            .map { ($0.eventID, $0) }
        )
    }

    // 설정 저장 (없으면 생성, 있으면 업데이트) + Supabase 동기화.
    // 로컬 저장이 끝나면 바로 돌아가고 업로드는 기다리지 않는다 (기존 동작 — 화면이 업로드를 기다리지 않게).
    func save(eventID: String, priority: Int, isPinned: Bool, category: String = "일반") async {
        let descriptor = FetchDescriptor<EventDisplaySettings>(
            predicate: #Predicate { $0.eventID == eventID }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.priority = priority
            existing.isPinned = isPinned
            existing.category = category
        } else {
            context.insert(
                EventDisplaySettings(eventID: eventID, priority: priority, isPinned: isPinned, category: category)
            )
        }
        try? context.save()

        Task {
            guard let userID = try? await supabase.auth.session.user.id.uuidString else { return }
            let row = EventDisplaySettingsUploadRow(
                userID: userID,
                eventID: eventID,
                priority: priority,
                isPinned: isPinned,
                category: category,
                updatedAt: Date()
            )
            _ = try? await supabase.from("event_display_settings")
                .upsert(row, onConflict: "user_id, event_id")
                .execute()
        }
    }
}

// MARK: - Combine 브리지 (#153 임시 — #156 에서 제거)
// fetchAll 은 프로토콜에 없고 홈 · 캘린더 ViewModel 이 구체 타입으로 직접 부른다 (#155 에서 정리).

extension EventDisplaySettingsRepository {
    func fetchAll() -> AnyPublisher<[String: EventDisplaySettings], Never> {
        .bridge { () async -> [String: EventDisplaySettings] in await self.fetchAll() }
    }

    func fetchAll(for eventIDs: [String]) -> AnyPublisher<[String: EventDisplaySettings], Never> {
        .bridge { () async -> [String: EventDisplaySettings] in await self.fetchAll(for: eventIDs) }
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
