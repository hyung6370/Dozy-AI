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
    case passwordSameAsCurrent
    case currentPasswordIncorrect
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
            return String(localized: "캘린더 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.")
        case .reminderAccessDenied:
            return String(localized: "미리알림 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.")
        case .calendarFetchFailed:
            return String(localized: "캘린더 일정을 불러오는 데 실패했습니다.")
        case .reminderFetchFailed:
            return String(localized: "미리알림을 불러오는 데 실패했습니다.")
        case .dataNotFound:
            return String(localized: "데이터를 찾을 수 없습니다.")
        case .saveFailed:
            return String(localized: "저장에 실패했습니다.")
        case .aiSummarizationFailed:
            return String(localized: "Dozy 요약 생성에 실패했습니다.")
        case .speechRecognitionFailed:
            return String(localized: "음성 인식에 실패했습니다.")
        case .unknown(let error):
            return String(localized: "알 수 없는 오류: \(error.localizedDescription)")
        case .googleSignInFailed:
            return String(localized: "Google 로그인에 실패했습니다. 다시 시도해주세요.")
        case .googleCalendarFetchFailed:
            return String(localized: "Google 캘린더를 불러오는 데 실패했습니다.")
        case .naverSignInFailed:
            return String(localized: "네이버 로그인에 실패했습니다.")
        case .naverCalendarFetchFailed:
            return String(localized: "네이버 캘린더를 불러오는 데 실패했습니다.")
        case .emailAuthFailed(let error):
            return String(localized: "이메일 로그인에 실패했습니다. (\(error.localizedDescription))")
        case .emailInvalid:
            return String(localized: "올바른 이메일 형식을 입력해주세요.")
        case .passwordTooShort:
            return String(localized: "비밀번호는 최소 \(PasswordPolicy.minLength)자 이상이어야 합니다.")
        case .emailAlreadyRegistered:
            return String(localized: "이미 존재하는 이메일입니다. 로그인 탭을 사용해주세요.")
        case .emailInvalidCredentials:
            return String(localized: "이메일 또는 비밀번호가 올바르지 않습니다.")
        case .passwordSameAsCurrent:
            return String(localized: "이전과 동일한 비밀번호입니다. 새로운 비밀번호로 변경해주세요.")
        case .currentPasswordIncorrect:
            return String(localized: "현재 비밀번호가 올바르지 않습니다.")
        case .calendarWriteFailed(let error):
            return String(localized: "캘린더 일정 수정/삭제에 실패했습니다. (\(error.localizedDescription))")
        case .calendarEventNotFound:
            return String(localized: "삭제할 일정을 찾을 수 없습니다. 이미 삭제되었거나 캘린더 접근 권한을 확인해주세요.")
        case .networkUnavailable:
            return String(localized: "네트워크에 연결되지 않았습니다. Wi-Fi 또는 셀룰러 연결을 확인해주세요.")
        case .googleCalendarWriteFailed(let statusCode):
            switch statusCode {
            case 401: return String(localized: "Google 인증이 만료되었습니다. 다시 로그인해주세요. (401)")
            case 403: return String(localized: "Google 캘린더 삭제 권한이 없습니다. (403)")
            case 404: return String(localized: "삭제할 Google 일정을 찾을 수 없습니다. (404)")
            default:  return String(localized: "Google 캘린더 삭제에 실패했습니다. (HTTP \(statusCode))")
            }
        case .sharedCalendarInvalidCode:
            return String(localized: "잘못된 초대 코드입니다.")
        case .sharedCalendarExpiredCode:
            return String(localized: "초대 코드가 만료되었습니다. 초대한 사람에게 새 코드를 요청해주세요.")
        case .sharedCalendarFull:
            return String(localized: "공유 캘린더는 최대 4명까지 참여할 수 있습니다.")
        case .sharedCalendarAlreadyMember:
            return String(localized: "이미 참여한 공유 캘린더입니다.")
        case .sharedCalendarNotOwner:
            return String(localized: "이 동작은 캘린더 소유자만 수행할 수 있습니다.")
        case .sharedCalendarInvalidName:
            return String(localized: "캘린더 이름을 입력해주세요.")
        case .sharedCalendarCodeGenerationFailed:
            return String(localized: "초대 코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요.")
        }
    }
}
