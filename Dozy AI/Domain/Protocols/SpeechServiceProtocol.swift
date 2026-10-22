//
//  SpeechServiceProtocol.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - Domain]
//  음성 인식 장치 서비스의 추상화. Speech/AVFoundation 은 Data 계층(SpeechService)만 안다.
//  UI 세션(시트가 떠 있는 동안)과 수명이 같고 결과를 메인에서만 소비하므로 프로토콜을
//  @MainActor 로 고정한다 — 구현체와 ViewModel 이 같은 액터에 있으면 내부 상태를 락 없이 다룬다.
//

import Foundation

/// SFSpeechRecognizer 권한 + 마이크 권한을 합친 도메인 표현
enum SpeechAuthorizationStatus: Equatable {
    case authorized
    case denied             // 사용자가 거부 -> 설정 앱 안내
    case restricted         // MDM 등 정책 차단
    case notDetermined
}

/// 인식 세션이 흘려보내는 이벤트
enum SpeechRecognitionEvent: Equatable {
    /// 말하는 중 계속 갱신되는 중간 결과. 매번 "지금까지의 전체 문장"이 온다
    case partial(String)
    /// 세션 종료 직전 1회 오는 확정 결과
    case final(String)
}

@MainActor
protocol SpeechServiceProtocol {
    /// 음성 인식 -> 마이크 순서로 권한 요청. 둘 다 허용돼야 .authorized
    func requestAuthorization() async -> SpeechAuthorizationStatus
    
    /// 마이크 캡쳐와 인식을 시작하고 결과 스트림을 돌려준다
    func startRecognition(locale: Locale) throws -> AsyncThrowingStream<SpeechRecognitionEvent, Error>
    
    /// 캡쳐를 멈추고 최종 결과를 요청. 세션이 없으면 no-op
    func stopRecognition()
}
