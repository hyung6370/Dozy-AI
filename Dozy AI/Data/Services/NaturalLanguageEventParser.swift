//
//  NaturalLanguageEventParser.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/22/26.
//
//  [Data Layer] 자연어 → EventDraft.
//  1) Apple Intelligence 가능하면 온디바이스 모델 (FoundationModelsEngine.eventDraft)
//  2) 아니면/실패하면 NSDataDetector 로 날짜·시각을 찾고 나머지 문장을 제목으로 쓰는 규칙 기반 폴백.
//

import Foundation
import OSLog

final class NaturalLanguageEventParser: EventParsingServiceProtocol {
    
    private let defaultDurationMinutes = 60
    
    func parseEvent(from text: String, referenceDate: Date) async throws -> EventDraft {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let engine = FoundationModelsEngine()
            if engine.status == .onDevice {
                do {
                    let response = try await engine.eventDraft(from: text, referenceDate: referenceDate)
                    if let draft = makeDraft(from: response) {
                        Logger.ai.info("[일정 파싱] 온디바이스 모델: \(draft.title, privacy: .public) @ \(draft.startDate)")
                        return draft
                    }
                    Logger.ai.error("[일정 파싱] 모델 응답의 날짜 형식 불량 → 폴백 (date=\(response.date, privacy: .public), time=\(response.startTime ?? "nil", privacy: .public))")
                } catch {
                    Logger.ai.error("[일정 파싱] 온디바이스 모델 실패 → 폴백: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
#endif
        return try parseWithDateDetector(text, referenceDate: referenceDate)
    }
    
    // MARK: - 온디바이스 응답 → Date 조립
    
#if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func makeDraft(from response: EventDraftResponse) -> EventDraft? {
        let calendar = Calendar.current
        
        // "YYYY-MM-DD"
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let day = dateFormatter.date(from: response.date.trimmingCharacters(in: .whitespaces)) else { return nil }
        
        var start = calendar.startOfDay(for: day)
        var isAllDay = true
        
        // "HH:mm" — 있으면 시각 일정
        if let time = response.startTime?.trimmingCharacters(in: .whitespaces), !time.isEmpty {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
            guard let withTime = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: start) else { return nil }
            start = withTime
            isAllDay = false
        }
        
        let minutes = max(5, response.durationMinutes)
        let end = isAllDay ? start : start.addingTimeInterval(TimeInterval(minutes * 60))
        
        let title = response.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = response.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return EventDraft(
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            location: (location?.isEmpty ?? true) ? nil : location,
            source: .onDevice
        )
    }
#endif
    
    // MARK: - 폴백 : NSDataDetector
    
    /// 날짜 표현을 찾아 시작 시각으로, 남은 문장을 제목으로. "30분"/"2시간" 같은 소요 표현은 종료 계산에 쓰고 제목에서 뺀다.
    private func parseWithDateDetector(_ text: String, referenceDate: Date) throws -> EventDraft {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            throw DozyError.eventParsingFailed
        }
        let nsText = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard let match = matches.first, let detected = match.date else {
            throw DozyError.eventParsingFailed
        }
        
        var remainder = nsText.replacingCharacters(in: match.range, with: " ")
        
        // 소요 시간: "30분", "1시간", "1시간 30분", "90 min", "2h"
        var durationMinutes = match.duration > 0 ? Int(match.duration / 60) : 0
        let durationPatterns = [
            "(\\d+)\\s*시간\\s*(\\d+)\\s*분", "(\\d+)\\s*시간", "(\\d+)\\s*분",
            "(\\d+)\\s*h", "(\\d+)\\s*min"
        ]
        for pattern in durationPatterns where durationMinutes == 0 {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(location: 0, length: (remainder as NSString).length)
            guard let m = regex.firstMatch(in: remainder, options: [], range: range) else { continue }
            let ns = remainder as NSString
            let first = Int(ns.substring(with: m.range(at: 1))) ?? 0
            let second = m.numberOfRanges > 2 ? (Int(ns.substring(with: m.range(at: 2))) ?? 0) : 0
            durationMinutes = pattern.contains("시간") || pattern.contains("h") ? first * 60 + second : first
            remainder = ns.replacingCharacters(in: m.range, with: " ")
        }
        if durationMinutes <= 0 { durationMinutes = defaultDurationMinutes }
        
        // 시각이 문장에 있었는지 — 없으면 종일로 본다
        let matchedText = nsText.substring(with: match.range)
        let hasTime = matchedText.range(of: "\\d\\s*시|\\d:\\d|오전|오후|am|pm", options: [.regularExpression, .caseInsensitive]) != nil
        let calendar = Calendar.current
        let start = hasTime ? detected : calendar.startOfDay(for: detected)
        let end = hasTime ? start.addingTimeInterval(TimeInterval(durationMinutes * 60)) : start
        
        // 제목 정리: 앞뒤 조사·공백 제거
        var title = remainder
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.replacingOccurrences(of: "^(에서|에|부터|까지)\\s*", with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: "\\s*(에서|에|부터|까지)$", with: "", options: .regularExpression)
        
        return EventDraft(
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: !hasTime,
            location: nil,
            source: .dateDetector
        )
    }
}
