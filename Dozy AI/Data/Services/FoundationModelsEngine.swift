//
//  FoundationModelsEngine.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/22/26.
//

/**
[Data Layer] Apple Foundation Models(온디바이스 LLM) 호출을 한 곳에 격리 한다.
 - 가용성 판별: SystemLanguageModel.default.availability -> AIEngineStatus
 - 일일 보고서: guided generation (@Generable DailyReportDraft) - 텍스트 파싱 없음
 - 한 줄 요약: 일반 텍스트 응답
 - 요청마다 새 LanguageModelSession - 이전 대화(transcript)가 섞이지 않게
 iOS 26 / macOS 26 미만에서는 타입 자체가 없으므로 호출부(AIService)가 #available로 감싼다.
 */

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels

// MARK: - 응답 스키마

/// 모델이 이 구조로 직접 응답한다. @Guide 설명은 모델에게 주는 필드별 지시이자 제약
@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "하루 업무 보고서")
struct DailyReportDraft {
    @Guide(description: "오늘 하루를 2~3문장으로 요약. 입력에 없는 사실은 지어내지 않는다")
    var summary: String
    
    @Guide(description: "핵심 성과나 주요 활동. 각 항목은 한 문장", .count(3...5))
    var highlights: [String]
    
    @Guide(description: "내일 우선적으로 해야 할 일. 미완료 항목과 오늘 흐름을 고려", .count(3))
    var nextActions: [String]
    
    @Guide(description: "오늘의 주요 업무 카테고리. 입력 데이터에 나온 카테고리 이름 중 하나, 없으면 '일반'")
    var category: String
    
    @Guide(description: "생산성 점수. 완료한 일과 일정 소화율 기준", .range(0.0...1.0))
    var score: Double
}

// MARK: - Engine

@available(iOS 26.0, macOS 26.0, *)
final class FoundationModelsEngine {
    
    private let model = SystemLanguageModel.default
    
    // MARK: - 가용성
    
    var status: AIEngineStatus {
        switch model.availability {
        case .available:
            return .onDevice
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
            case .modelNotReady: return .modelNotReady
            @unknown default: return .unavailable
            }
        }
    }
    
    // MARK: - 세션 지시문 (system prompt 역할)
    
    /// 형식은 @Generable 이 강제하므로 여기서는 역할·언어·톤·금지사항만 준다.
    private var reportInstructions: String {
        let language = Locale.current.language.languageCode?.identifier == "ko" ? "한국어" : "English"
        return """
            You are a concise daily work-journal assistant inside a personal productivity app.
            Write in \(language). Be specific and grounded: only use facts present in the user's data.
            Do not invent events, people, or numbers. Keep a warm, neutral tone without emojis.
            Prefer the user's own category names when choosing the category.
            """
    }
    
    private var quickLineInstructions: String {
        let language = Locale.current.language.languageCode?.identifier == "ko" ? "한국어" : "English"
        return """
            You summarize a day's schedule in one short sentence for a voice assistant.
            Write in \(language), under 40 characters, no emojis, no list, no line breaks.
            """
    }
    
    // MARK: - 호출
    
    /// 일일 보고서 - guided generation
    func dailyReport(prompt: String) async throws -> DailyReportDraft {
        let session = LanguageModelSession(model: model, instructions: reportInstructions)
        let response = try await session.respond(
            to: prompt,
            generating: DailyReportDraft.self,
            options: GenerationOptions(temperature: 0.4)
        )
        return response.content
    }
    
    /// 한 줄 요약 - 일반 텍스트
    func quickLine(prompt: String) async throws -> String {
        let session = LanguageModelSession(model: model, instructions: quickLineInstructions)
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(temperature: 0.3)
        )
        return response.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }
    
    /// 첫 호출 지연을 줄이려면 홈 진입 시 한 번 불러 둔다
    func prewarm() {
        guard status == .onDevice else { return }
        LanguageModelSession(model: model, instructions: reportInstructions).prewarm()
    }
}
#endif
