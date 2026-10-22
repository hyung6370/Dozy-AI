//
//  AIEngineStatus.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/22/26.
//

/**
 요약을 어떤 엔진이 만들 수 있는지 - 설정 화면 표시용 도메인 표현
 FoundationModels의 SystemLanguageModel.Availability를 Data 계층(FoundationModelsEngine)이 이 타입으로 바꿔 준다.
 */

import Foundation

enum AIEngineStatus: Equatable {
    case onDevice // 온디바이스 모델 사용 가능 (iOS 26+, Apple Intelligence 켜짐, 모델 준비 됨)
    case onDeviceFailed // 사용 가능하다고 보고됐지만 최근 생성이 실패해 규칙 기반으로 폴백한 상태 (모델 자산 미다운로드 등)
    case deviceNotEligible // 기기 미지원 또는 OS가 iOS 26 미만
    case appleIntelligenceOff // 설정에서 애플 인텔리전스가 꺼져 있음
    case modelNotReady // 모델 다운로드/준비 중 - 잠시 뒤 다시 시도하면 될 수 있음
    case unavailable // 그 외 사유로 불가 -> 규칙 기반 요약
    
    var usesOnDeviceModel: Bool { self == .onDevice }
    
    /// 설정 화면 "AI 엔진" 행에 보여줄 문구
    var displayName: String {
        switch self {
        case .onDevice:             return String(localized: "Apple Intelligence")
        case .onDeviceFailed:       return String(localized: "Apple Intelligence (최근 실패, 기본 분석 사용)")
        case .deviceNotEligible:    return String(localized: "기본 분석 (기기 미지원)")
        case .appleIntelligenceOff: return String(localized: "기본 분석 (Apple Intelligence 꺼짐)")
        case .modelNotReady:        return String(localized: "준비 중")
        case .unavailable:          return String(localized: "기본 분석")
        }
    }
}
