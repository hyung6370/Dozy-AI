//
//  DozyError.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/24/26.
//

import Foundation

enum DozyError: LocalizedError {
    case calendarAccessDenied
    case reminderAccessDenied
    case calendarFetchFailed(underlying: Error)
    case reminderFetchFailed(underlying: Error)
    case dataNotFound
    case saveFailed(underlying: Error)
    case aiSummarizationFailed
    case speechRecognitionFailed
    case unknown(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "캘린더 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
        case .reminderAccessDenied:
            return "미리알림 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
        case .calendarFetchFailed:
            return "캘린더 일정을 불러오는 데 실패했습니다."
        case .reminderFetchFailed:
            return "미리알림을 불러오는 데 실패했습니다."
        case .dataNotFound:
            return "데이터를 찾을 수 없습니다."
        case .saveFailed:
            return "저장에 실패했습니다."
        case .aiSummarizationFailed:
            return "AI 요약 생성에 실패했습니다."
        case .speechRecognitionFailed:
            return "음성 인식에 실패했습니다."
        case .unknown(let error):
            return "알 수 없는 오류: \(error.localizedDescription)"
        }
    }
}
