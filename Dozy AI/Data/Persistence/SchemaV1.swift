//
//  SchemaV1.swift
//  Dozy AI
//

import SwiftData

// MARK: - V1: UserCategory 추가 이전

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            WorkLog.self,
            UserPattern.self,
            DozyEvent.self,
            EventCompletion.self,
            NotificationRecord.self,
            EventDisplaySettings.self
        ]
    }
}

// MARK: - V2: UserCategory (id, updatedAt 포함) 추가

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            WorkLog.self,
            UserPattern.self,
            DozyEvent.self,
            EventCompletion.self,
            NotificationRecord.self,
            EventDisplaySettings.self,
            UserCategory.self
        ]
    }
}

// MARK: - Migration Plan

enum DozyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
