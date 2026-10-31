//
//  DozySchema.swift
//  Dozy AI
//
//  App Group 의 default.store 를 여는 모든 곳이 쓰는 단일 SwiftData 스키마.
//  앱(DependencyContainer) · 위젯(TodayEventsDataSource · ToggleEventCompletionIntent) · Siri 인텐트(AppIntentStore) ·
//  Live Activity 독립 훅(AppDelegate)이 모두 이 목록으로 연다.
//
//  ⚠️ 부분 스키마로 같은 store 를 열면 SwiftData 가 스키마에 없는 모델의 테이블을 지운다(자동 마이그레이션).
//  앱이 열어 둔 컨테이너는 다음 저장에서 "default.store 파일을 열 수 없습니다"(NSSQLiteErrorDomain=1)로 실패하고,
//  지워진 테이블의 데이터(메모 · 요약)는 사라진다. 모델을 추가할 때는 여기에만 넣는다.
//

import SwiftData

nonisolated enum DozySchema {
    static var models: [any PersistentModel.Type] {
        [
            WorkLog.self, UserPattern.self, DozyEvent.self,
            EventCompletion.self, NotificationRecord.self,
            EventDisplaySettings.self, UserCategory.self,
            TodayEventCache.self
        ]
    }

    static var schema: Schema { Schema(models) }
}
