//
//  MacCalendarViewMode.swift
//  Dozy AI (macOS)
//
//  Phase 2a — 캘린더 뷰 모드 (월/주/일)
//

import Foundation

enum MacCalendarViewMode: String, CaseIterable, Identifiable, Hashable {
    case month
    case week
    case day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "월"
        case .week:  return "주"
        case .day:   return "일"
        }
    }
}
