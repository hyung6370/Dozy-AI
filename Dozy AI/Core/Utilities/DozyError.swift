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
    case googleSignInFailed(underlying: Error?)
    case googleCalendarFetchFailed
    case naverSignInFailed
    case emailAuthFailed(underlying: Error)
    case emailInvalid
    case passwordTooShort
    case emailAlreadyRegistered
    case emailInvalidCredentials
    case naverCalendarFetchFailed
    case calendarWriteFailed(underlying: Error)
    case calendarEventNotFound
    case googleCalendarWriteFailed(statusCode: Int)
    case networkUnavailable
    // Shared Calendar
    case sharedCalendarInvalidCode
    case sharedCalendarExpiredCode
    case sharedCalendarFull
    case sharedCalendarAlreadyMember(calendarID: String)
    case sharedCalendarNotOwner
    case sharedCalendarInvalidName
    case sharedCalendarCodeGenerationFailed

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
            return "Dozy 요약 생성에 실패했습니다."
        case .speechRecognitionFailed:
            return "음성 인식에 실패했습니다."
        case .unknown(let error):
            return "알 수 없는 오류: \(error.localizedDescription)"
        case .googleSignInFailed:
            return "Google 로그인에 실패했습니다. 다시 시도해주세요."
        case .googleCalendarFetchFailed:
            return "Google 캘린더를 불러오는 데 실패했습니다."
        case .naverSignInFailed:
            return "네이버 로그인에 실패했습니다."
        case .naverCalendarFetchFailed:
            return "네이버 캘린더를 불러오는 데 실패했습니다."
        case .emailAuthFailed(let error):
            return "이메일 로그인에 실패했습니다. (\(error.localizedDescription))"
        case .emailInvalid:
            return "올바른 이메일 형식을 입력해주세요."
        case .passwordTooShort:
            return "비밀번호는 최소 6자 이상이어야 합니다."
        case .emailAlreadyRegistered:
            return "이미 가입된 이메일입니다. 기존 로그인 방식(Apple/Google)으로 시도하거나 로그인 탭을 사용해주세요."
        case .emailInvalidCredentials:
            return "이메일 또는 비밀번호가 올바르지 않습니다."
        case .calendarWriteFailed(let error):
            return "캘린더 일정 수정/삭제에 실패했습니다. (\(error.localizedDescription))"
        case .calendarEventNotFound:
            return "삭제할 일정을 찾을 수 없습니다. 이미 삭제되었거나 캘린더 접근 권한을 확인해주세요."
        case .networkUnavailable:
            return "네트워크에 연결되지 않았습니다. Wi-Fi 또는 셀룰러 연결을 확인해주세요."
        case .googleCalendarWriteFailed(let statusCode):
            switch statusCode {
            case 401: return "Google 인증이 만료되었습니다. 다시 로그인해주세요. (401)"
            case 403: return "Google 캘린더 삭제 권한이 없습니다. (403)"
            case 404: return "삭제할 Google 일정을 찾을 수 없습니다. (404)"
            default:  return "Google 캘린더 삭제에 실패했습니다. (HTTP \(statusCode))"
            }
        case .sharedCalendarInvalidCode:
            return "잘못된 초대 코드입니다."
        case .sharedCalendarExpiredCode:
            return "초대 코드가 만료되었습니다. 상대에게 새 코드를 요청해주세요."
        case .sharedCalendarFull:
            return "공유 캘린더는 최대 2명까지 참여할 수 있습니다."
        case .sharedCalendarAlreadyMember:
            return "이미 참여한 공유 캘린더입니다."
        case .sharedCalendarNotOwner:
            return "이 동작은 캘린더 소유자만 수행할 수 있습니다."
        case .sharedCalendarInvalidName:
            return "캘린더 이름을 입력해주세요."
        case .sharedCalendarCodeGenerationFailed:
            return "초대 코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요."
        }
    }
}
