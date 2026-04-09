//
//  WorkLog.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class WorkLog {
    
    // MARK: - 식별
    @Attribute(.unique)
    var id: UUID
    var date: Date
    
    // MARK: - 원본 데이터 (AI 입력으로 사용)
    var rawEventTitles: [String]       // 캘린더 이벤트 제목들
    var rawEventDetails: [String]      // 이벤트 상세 (시간+제목+장소)
    var completedTaskTitles: [String]  // 완료한 할 일 제목들
    var memos: [String]                // 사용자가 직접 입력한 메모
    
    // MARK: - AI 생성 결과 (Phase 2에서 채워짐)
    var aiSummary: String              // AI 요약 텍스트
    var highlights: [String]           // 핵심 하이라이트
    var nextActions: [String]          // 추천 다음 할 일
    
    // MARK: - 메타데이터
    var category: String               // 주요 업무 카테고리
    var productivityScore: Double?     // 생산성 점수 (0.0 ~ 1.0)
    var createdAt: Date
    var updatedAt: Date
    
    init(date: Date) {
        self.id = UUID()
        self.date = date.startOfDay     // 항상 날짜의 시작으로 정규화
        self.rawEventTitles = []
        self.rawEventDetails = []
        self.completedTaskTitles = []
        self.memos = []
        self.aiSummary = ""
        self.highlights = []
        self.nextActions = []
        self.category = WorkCategory.general.rawValue
        self.productivityScore = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 캘린더 이벤트 데이터를 채움
    func populate(with events: [CalendarEvent]) {
        self.rawEventTitles = events.map { $0.title }
        self.rawEventDetails = events.map { $0.contextString }
        self.updatedAt = Date()
    }
    
    /// 완료된 할 일 데이터를 채움
    func populate(with tasks: [TaskItem]) {
        self.completedTaskTitles = tasks.map { $0.title }
        self.updatedAt = Date()
    }
    
    /// 메모 추가
    func addMemo(_ memo: String) {
        guard !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.memos.append(memo)
        self.updatedAt = Date()
    }

    /// 메모 수정
    func updateMemo(at index: Int, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < memos.count, !trimmed.isEmpty else { return }
        memos[index] = trimmed
        updatedAt = Date()
    }

    /// 메모 삭제
    func deleteMemo(at index: Int) {
        guard index >= 0, index < memos.count else { return }
        memos.remove(at: index)
        updatedAt = Date()
    }
    
    /// 오늘 날짜의 로그인지 확인
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// 전체 컨텍스트를 AI 프롬프트용 텍스트로 변환
    var fullContextString: String {
        var sections: [String] = []
        
        if !rawEventDetails.isEmpty {
            sections.append("## 오늘의 일정\n" + rawEventDetails.joined(separator: "\n"))
        }
        if !completedTaskTitles.isEmpty {
            sections.append("## 완료한 할 일\n" + completedTaskTitles.map { "✅ \($0)" }.joined(separator: "\n"))
        }
        if !memos.isEmpty {
            sections.append("## 메모\n" + memos.map { "📝 \($0)" }.joined(separator: "\n"))
        }
        
        return sections.joined(separator: "\n\n")
    }
}

// @Model 내부에서는 String으로 저장하고, enm은 변환용으로 사용
enum WorkCategory: String, Codable, CaseIterable {
    case development = "개발"
    case meeting = "회의"
    case planning = "기획"
    case documentation = "문서"
    case review = "리뷰"
    case exercise = "운동"
    case meal = "식사"
    case medical = "병원"
    case study = "공부"
    case travel = "여행"
    case shopping = "쇼핑"
    case family = "가족"
    case hobby = "취미"
    case general = "일반"

    var emoji: String {
        switch self {
        case .development:   return "💻"
        case .meeting:       return "🤝"
        case .planning:      return "📋"
        case .documentation: return "📄"
        case .review:        return "🔍"
        case .exercise:      return "🏋️"
        case .meal:          return "🍽️"
        case .medical:       return "🏥"
        case .study:         return "📚"
        case .travel:        return "✈️"
        case .shopping:      return "🛍️"
        case .family:        return "👨‍👩‍👧"
        case .hobby:         return "🎮"
        case .general:       return "📌"
        }
    }
}
