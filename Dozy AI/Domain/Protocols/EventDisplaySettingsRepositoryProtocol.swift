//
//  EventDisplaySettingsRepositoryProtocol.swift
//  Dozy AI
//
//  외부(Apple · Google) 일정의 우선순위 · 고정 · 카테고리 저장 (#72 선행 리팩터링).
//  구현은 Data 의 EventDisplaySettingsRepository. 검색 화면 ViewModel 이 UseCase 로만 접근하도록 분리.
//

import Foundation
import Combine

protocol EventDisplaySettingsRepositoryProtocol {
    /// 없으면 생성, 있으면 갱신 + Supabase 동기화
    func save(eventID: String, priority: Int, isPinned: Bool, category: String) -> AnyPublisher<Void, Never>
}
