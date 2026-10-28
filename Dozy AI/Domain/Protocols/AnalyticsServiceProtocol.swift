//
//  AnalyticsServiceProtocol.swift
//  Dozy AI
//
//  애널리틱스 추상화 (#90). 구현은 Data 의 FirebaseAnalyticsService. Domain · UseCase 는 이 프로토콜만 안다 —
//  SDK 를 바꾸면 Data 파일 하나만 바뀐다.
//

import Foundation

protocol AnalyticsServiceProtocol: AnyObject {
    func track(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, for property: AnalyticsUserProperty)
    /// 설정 "사용 통계 전송" 토글. false 면 이후 이벤트를 보내지 않는다.
    func setCollectionEnabled(_ enabled: Bool)
}

/// 아무것도 보내지 않는 구현. 테스트 기본값 · Firebase 설정 파일이 없을 때 쓴다.
final class NoopAnalyticsService: AnalyticsServiceProtocol {
    init() {}
    func track(_ event: AnalyticsEvent) {}
    func setUserProperty(_ value: String?, for property: AnalyticsUserProperty) {}
    func setCollectionEnabled(_ enabled: Bool) {}
}
