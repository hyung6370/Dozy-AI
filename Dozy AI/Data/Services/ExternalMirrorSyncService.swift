//
//  ExternalMirrorSyncService.swift
//  Dozy AI
//
//  Phase D: 외부(Apple/Google) 원본과 Dozy 미러 스냅샷의 단방향 동기화.
//  사용자 기기에서만 실행되며, 본인이 소유한 미러 스냅샷만 대상으로 한다.
//

import Foundation
import Combine
import OSLog

final class ExternalMirrorSyncService {

    /// 원본이 삭제된 상태로 유예 기간을 넘긴 스냅샷을 실제로 삭제하는 TTL.
    /// externalLastSyncedAt은 최초 deleted 마킹 시에만 갱신되므로 "마킹 이후 경과 시간"으로 동작한다.
    static let staleMirrorTTL: TimeInterval = 3 * 24 * 60 * 60

    private let repository: DozyEventRepositoryProtocol
    private let appleService: CalendarService
    private let googleService: GoogleCalendarService
    private let sourceManager: CalendarSourceManager

    /// 한 번에 여러 reconcile이 돌지 않도록 직렬화.
    private var inFlight: AnyCancellable?

    init(
        repository: DozyEventRepositoryProtocol,
        appleService: CalendarService,
        googleService: GoogleCalendarService,
        sourceManager: CalendarSourceManager
    ) {
        self.repository = repository
        self.appleService = appleService
        self.googleService = googleService
        self.sourceManager = sourceManager
    }

    /// 비동기로 reconcile 실행. 이미 진행 중이면 무시한다.
    /// completion은 실패/성공 무관하게 한 번 호출되며, 호출자는 이 시점에 UI를 refresh하면 된다.
    func reconcile(completion: (() -> Void)? = nil) {
        guard inFlight == nil else {
            Logger.mirrorSync.debug("[동기화] ⏭ 이미 reconcile 진행 중 — 스킵")
            completion?()
            return
        }
        Logger.mirrorSync.info("[동기화] 🔄 외부 미러 reconcile 시작")
        inFlight = repository.fetchMyExternalMirrors()
            .flatMap { [weak self] mirrors -> AnyPublisher<ReconcileResult, DozyError> in
                guard let self else {
                    return Just(ReconcileResult.empty).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.computeReconcile(mirrors: mirrors)
            }
            .flatMap { [weak self] result -> AnyPublisher<Void, DozyError> in
                guard let self else {
                    return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                Logger.mirrorSync.info("[동기화] 📝 업데이트 \(result.updates.count)건 / 삭제 마킹 \(result.deletedIDs.count)건 / 영구 삭제 \(result.permanentDeleteIDs.count)건")
                // 먼저 flag/필드 반영 → 그 다음 유예 지난 스냅샷 영구 삭제.
                // 순서를 뒤집으면 방금 삭제한 id에 대해 apply 단계에서 no-op이 되므로 결과적으로는 같지만, 의미상 마킹 먼저가 자연스러움.
                return self.repository.applyExternalMirrorReconcile(
                    updates: result.updates,
                    deletedIDs: result.deletedIDs
                )
                .flatMap { [weak self] _ -> AnyPublisher<Void, DozyError> in
                    guard let self else {
                        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                    }
                    guard !result.permanentDeleteIDs.isEmpty else {
                        return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                    }
                    return self.repository.deleteExternalMirrors(ids: result.permanentDeleteIDs)
                }
                .eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        Logger.mirrorSync.error("[동기화] ❌ reconcile 실패: \(error.localizedDescription)")
                    } else {
                        Logger.mirrorSync.info("[동기화] ✅ reconcile 완료")
                    }
                    self?.inFlight = nil
                    completion?()
                },
                receiveValue: { _ in }
            )
    }

    /// reconcile 결과 집계.
    private struct ReconcileResult {
        let updates: [ExternalMirrorUpdate]
        let deletedIDs: [String]
        let permanentDeleteIDs: [String]

        static let empty = ReconcileResult(updates: [], deletedIDs: [], permanentDeleteIDs: [])
    }

    // MARK: - 계산 로직

    /// 미러 스냅샷을 source별로 나누고, 각 source의 원본을 범위 fetch한 뒤 매칭 결과를 돌려준다.
    private func computeReconcile(
        mirrors: [DozyEvent]
    ) -> AnyPublisher<ReconcileResult, DozyError> {
        guard !mirrors.isEmpty else {
            return Just(ReconcileResult.empty).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }

        let appleMirrors = mirrors.filter { $0.externalSource == CalendarSource.apple.rawValue }
        let googleMirrors = mirrors.filter { $0.externalSource == CalendarSource.google.rawValue }

        let applePublisher = reconcilePublisher(
            for: .apple,
            mirrors: appleMirrors,
            fetch: { [weak self] start, end in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.appleService.fetchEvents(from: start, to: end)
            }
        )

        let googlePublisher = reconcilePublisher(
            for: .google,
            mirrors: googleMirrors,
            fetch: { [weak self] start, end in
                guard let self else {
                    return Just([]).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.googleService.fetchEvents(from: start, to: end)
                    .replaceError(with: []).setFailureType(to: DozyError.self).eraseToAnyPublisher()
            }
        )

        return Publishers.Zip(applePublisher, googlePublisher)
            .map { apple, google in
                ReconcileResult(
                    updates: apple.updates + google.updates,
                    deletedIDs: apple.deletedIDs + google.deletedIDs,
                    permanentDeleteIDs: apple.permanentDeleteIDs + google.permanentDeleteIDs
                )
            }
            .eraseToAnyPublisher()
    }

    private func reconcilePublisher(
        for source: CalendarSource,
        mirrors: [DozyEvent],
        fetch: @escaping (Date, Date) -> AnyPublisher<[CalendarEvent], DozyError>
    ) -> AnyPublisher<ReconcileResult, DozyError> {
        guard !mirrors.isEmpty else {
            return Just(ReconcileResult.empty).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        // 해당 소스가 비활성화면 원본 조회 불가 → 이번 사이클은 skip (삭제 마킹도 하지 않음).
        guard sourceManager.isEnabled(source) else {
            Logger.mirrorSync.info("ℹ️ \(source.rawValue) 소스 비활성 — 이번 reconcile은 skip")
            return Just(ReconcileResult.empty).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }

        let cal = Calendar.current
        let minStart = mirrors.map(\.startDate).min() ?? Date()
        let maxEnd = mirrors.map(\.endDate).max() ?? Date()
        // 넉넉하게 ±1일 패딩 — 타임존 경계/원본 시간 이동 대비.
        let rangeStart = cal.date(byAdding: .day, value: -1, to: minStart) ?? minStart
        let rangeEnd = cal.date(byAdding: .day, value: 1, to: maxEnd) ?? maxEnd
        let ttl = Self.staleMirrorTTL

        return fetch(rangeStart, rangeEnd)
            .map { origins -> ReconcileResult in
                let originsByID = Dictionary(uniqueKeysWithValues: origins.map { ($0.id, $0) })
                var updates: [ExternalMirrorUpdate] = []
                var deletedIDs: [String] = []
                var permanentDeleteIDs: [String] = []
                let now = Date()

                for mirror in mirrors {
                    guard let extID = mirror.externalEventID else { continue }
                    if let origin = originsByID[extID] {
                        if Self.hasDrift(mirror: mirror, origin: origin) || mirror.externalDeleted {
                            updates.append(ExternalMirrorUpdate(
                                id: mirror.id,
                                title: origin.title,
                                startDate: origin.startDate,
                                endDate: origin.endDate,
                                isAllDay: origin.isAllDay,
                                location: origin.location,
                                notes: origin.notes,
                                colorHex: origin.calendarColorHex
                            ))
                        }
                    } else if !mirror.externalDeleted {
                        // 처음 원본 누락 감지 — 마킹만. externalLastSyncedAt이 now로 갱신되며
                        // 이게 유예 기간의 기준 타임스탬프가 된다.
                        deletedIDs.append(mirror.id)
                    } else if let syncedAt = mirror.externalLastSyncedAt,
                              now.timeIntervalSince(syncedAt) >= ttl {
                        // 이미 deleted 상태에서 유예 기간(3일)이 지났고 여전히 원본 없음 → 영구 삭제.
                        permanentDeleteIDs.append(mirror.id)
                    }
                    // else: deleted 상태이나 유예 내 — 아무것도 안 하고 유지.
                }
                return ReconcileResult(
                    updates: updates,
                    deletedIDs: deletedIDs,
                    permanentDeleteIDs: permanentDeleteIDs
                )
            }
            .eraseToAnyPublisher()
    }

    /// 스냅샷 필드와 원본 필드 간 차이가 있는지.
    private static func hasDrift(mirror: DozyEvent, origin: CalendarEvent) -> Bool {
        if mirror.title != origin.title { return true }
        if mirror.startDate != origin.startDate { return true }
        if mirror.endDate != origin.endDate { return true }
        if mirror.isAllDay != origin.isAllDay { return true }
        if mirror.location != origin.location { return true }
        if mirror.notes != origin.notes { return true }
        if mirror.colorHex != origin.calendarColorHex { return true }
        return false
    }
}

private extension Logger {
    static let mirrorSync = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dozy", category: "MirrorSync")
}
