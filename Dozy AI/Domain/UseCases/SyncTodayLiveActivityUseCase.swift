//
//  SyncTodayLiveActivityUseCase.swift
//  Dozy AI
//
//  [UseCase] 위젯 캐시(오늘 머지 일정) → TodayAgendaPlanner → Live Activity 반영.
//  호출 시점: 캐시 저장 직후(훅), 포그라운드 복귀, 백그라운드 갱신, 설정 토글.
//  설정이 꺼져 있으면 무조건 내린다.
//

import Foundation

final class SyncTodayLiveActivityUseCase {

    private let service: LiveActivityServiceProtocol
    private let loadItems: @MainActor () -> [TodayAgendaItem]
    private let isEnabled: () -> Bool

    init(
        service: LiveActivityServiceProtocol,
        loadItems: @escaping @MainActor () -> [TodayAgendaItem],
        isEnabled: @escaping () -> Bool = { LiveActivitySettings.isEnabled() }
    ) {
        self.service = service
        self.loadItems = loadItems
        self.isEnabled = isEnabled
    }

    /// 현재 캐시와 시각으로 계획을 세워 반영한다. 반영한 계획을 돌려줘 호출자가 로그·테스트에 쓸 수 있다.
    @MainActor
    @discardableResult
    func execute(now: Date = Date()) async -> TodayAgendaPlan {
        guard isEnabled() else {
            await service.endAll()
            return .end
        }
        let plan = TodayAgendaPlanner.plan(items: loadItems(), now: now)
        await service.apply(plan)
        return plan
    }

    /// 설정을 끌 때 — 즉시 전부 내린다.
    @MainActor
    func endAll() async {
        await service.endAll()
    }
}
