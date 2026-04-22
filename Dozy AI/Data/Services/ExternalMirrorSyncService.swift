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
            Logger.mirrorSync.debug("⏭ 이미 reconcile 진행 중 — 스킵")
            completion?()
            return
        }
        Logger.mirrorSync.info("🔄 외부 미러 reconcile 시작")
        inFlight = repository.fetchMyExternalMirrors()
            .flatMap { [weak self] mirrors -> AnyPublisher<(updates: [ExternalMirrorUpdate], deletedIDs: [String]), DozyError> in
                guard let self else {
                    return Just((updates: [], deletedIDs: [])).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                return self.computeReconcile(mirrors: mirrors)
            }
            .flatMap { [weak self] result -> AnyPublisher<Void, DozyError> in
                guard let self else {
                    return Just(()).setFailureType(to: DozyError.self).eraseToAnyPublisher()
                }
                Logger.mirrorSync.info("📝 업데이트 \(result.updates.count)건 / 삭제 마킹 \(result.deletedIDs.count)건")
                return self.repository.applyExternalMirrorReconcile(
                    updates: result.updates,
                    deletedIDs: result.deletedIDs
                )
            }
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        Logger.mirrorSync.error("❌ reconcile 실패: \(error.localizedDescription)")
                    } else {
                        Logger.mirrorSync.info("✅ reconcile 완료")
                    }
                    self?.inFlight = nil
                    completion?()
                },
                receiveValue: { _ in }
            )
    }

    // MARK: - 계산 로직

    /// 미러 스냅샷을 source별로 나누고, 각 source의 원본을 범위 fetch한 뒤 매칭 결과를 돌려준다.
    private func computeReconcile(
        mirrors: [DozyEvent]
    ) -> AnyPublisher<(updates: [ExternalMirrorUpdate], deletedIDs: [String]), DozyError> {
        guard !mirrors.isEmpty else {
            return Just((updates: [], deletedIDs: [])).setFailureType(to: DozyError.self).eraseToAnyPublisher()
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
                (updates: apple.updates + google.updates,
                 deletedIDs: apple.deletedIDs + google.deletedIDs)
            }
            .eraseToAnyPublisher()
    }

    private func reconcilePublisher(
        for source: CalendarSource,
        mirrors: [DozyEvent],
        fetch: @escaping (Date, Date) -> AnyPublisher<[CalendarEvent], DozyError>
    ) -> AnyPublisher<(updates: [ExternalMirrorUpdate], deletedIDs: [String]), DozyError> {
        guard !mirrors.isEmpty else {
            return Just((updates: [], deletedIDs: [])).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }
        // 해당 소스가 비활성화면 원본 조회 불가 → 이번 사이클은 skip (삭제 마킹도 하지 않음).
        guard sourceManager.isEnabled(source) else {
            Logger.mirrorSync.info("ℹ️ \(source.rawValue) 소스 비활성 — 이번 reconcile은 skip")
            return Just((updates: [], deletedIDs: [])).setFailureType(to: DozyError.self).eraseToAnyPublisher()
        }

        let cal = Calendar.current
        let minStart = mirrors.map(\.startDate).min() ?? Date()
        let maxEnd = mirrors.map(\.endDate).max() ?? Date()
        // 넉넉하게 ±1일 패딩 — 타임존 경계/원본 시간 이동 대비.
        let rangeStart = cal.date(byAdding: .day, value: -1, to: minStart) ?? minStart
        let rangeEnd = cal.date(byAdding: .day, value: 1, to: maxEnd) ?? maxEnd

        return fetch(rangeStart, rangeEnd)
            .map { origins -> (updates: [ExternalMirrorUpdate], deletedIDs: [String]) in
                let originsByID = Dictionary(uniqueKeysWithValues: origins.map { ($0.id, $0) })
                var updates: [ExternalMirrorUpdate] = []
                var deletedIDs: [String] = []

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
                        deletedIDs.append(mirror.id)
                    }
                }
                return (updates, deletedIDs)
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
