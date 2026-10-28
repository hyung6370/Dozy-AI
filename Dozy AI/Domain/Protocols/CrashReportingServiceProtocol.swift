//
//  CrashReportingServiceProtocol.swift
//  Dozy AI
//
//  크래시 · 비치명 오류 보고 추상화 (#117). 구현은 Data 의 FirebaseCrashReportingService.
//
//  비치명 오류는 Data 서비스 깊은 곳(동기화 · AI 폴백 · Realtime)에서 나는데, 그 서비스들을 전부 DI 로
//  바꾸면 생성자 변경이 수십 군데로 번진다. 그래서 `CrashReporting.current` 정적 진입점을 둔다 —
//  DependencyContainer 가 앱 시작 때 실제 구현을 꽂고, 테스트는 Mock 을 꽂는다 (AppIntentStore 와 같은 패턴).
//
//  사용자 콘텐츠 보호: 기록하는 오류는 `sanitized(_:context:)` 를 거쳐 도메인 · 코드 · 타입 이름만 남긴다.
//  Supabase · SwiftData 오류 메시지에는 요청 본문이나 일정 제목이 섞일 수 있어 localizedDescription 을 버린다.
//

import Foundation

// 백그라운드(동기화 · Realtime)에서도 부르므로 메인 액터에 묶지 않는다 — iOS 타깃은 기본 격리가 MainActor.
nonisolated protocol CrashReportingServiceProtocol: AnyObject {
    /// 비치명 오류 기록. `context` 는 어디서 실패했는지 나타내는 고정 문자열 (예: "sync.upload.dozy_events").
    func record(_ error: Error, context: String)
    /// 크래시 직전 맥락용 짧은 로그 (사용자 콘텐츠 금지).
    func log(_ message: String)
    /// 설정 "사용 통계 전송" 토글. false 면 이후 크래시 · 오류를 보내지 않는다.
    func setCollectionEnabled(_ enabled: Bool)
}

nonisolated final class NoopCrashReportingService: CrashReportingServiceProtocol {
    init() {}
    func record(_ error: Error, context: String) {}
    func log(_ message: String) {}
    func setCollectionEnabled(_ enabled: Bool) {}
}

nonisolated enum CrashReporting {
    /// 앱 전역 보고기. 기본은 Noop — DependencyContainer 가 Firebase 구현으로 바꾼다.
    nonisolated(unsafe) static var current: CrashReportingServiceProtocol = NoopCrashReportingService()

    /// Data 서비스에서 부르는 짧은 진입점.
    static func record(_ error: Error, context: String) {
        current.record(error, context: context)
    }

    /// 사용자 콘텐츠가 섞일 수 있는 메시지를 버리고 분류 정보만 남긴 오류.
    /// - domain: `dozy.<context>` — 대시보드에서 실패 지점별로 묶인다
    /// - code: 원래 오류 코드
    /// - userInfo: 원래 오류의 타입 이름 · 원래 도메인만
    static func sanitized(_ error: Error, context: String) -> NSError {
        let ns = error as NSError
        return NSError(
            domain: "dozy.\(context)",
            code: ns.code,
            userInfo: [
                "error_type": String(describing: type(of: error)),
                "underlying_domain": ns.domain,
            ]
        )
    }
}
