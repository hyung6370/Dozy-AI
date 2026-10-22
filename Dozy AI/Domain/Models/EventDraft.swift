//
//  EventDraft.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 10/22/26.
//

import Foundation

struct EventDraft: Equatable {
    enum Source: Equatable {
        case onDevice       // Apple Intelligence
        case dateDetector   // NSDataDetector 폴백
    }
    
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var source: Source
    
    /// 사용자에게 보여 줄 "무엇으로 해석했는지" 힌트
    var sourceLabel: String {
        switch source {
        case .onDevice: return String(localized: "Apple Intelligence")
        case .dateDetector: return String(localized: "날짜 인식")
        }
    }
}
