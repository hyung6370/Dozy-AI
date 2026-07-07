//
//  AuthStyles.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 7/2/26.
//

import SwiftUI

// MARK: - Auth Field Style

/// 로그인/회원가입 화면의 이메일·OTP·비밀번호 필드 공통 스타일.
/// 기본 .textFieldStyle(.roundedBorder) 는 모서리 radius 가 작고 다크모드에서
/// 경계가 흐릿해서, 로그인 버튼들과 일관된 cornerRadius 10 + separator
/// stroke 로 통일.
extension View {
    func dozyAuthFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator), lineWidth: 1)
            }
    }
}

// MARK: - Auth Button Styles

/// Apple 로그인·이메일 제출 등 주요 액션 버튼 — primary 배경 반전 스타일.
struct DozyAuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline).fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Google 로그인 등 보조 버튼 — 다크모드에서 systemGray6 배경이 페이지와 거의
/// 동일한 어두운 회색이라 경계가 묻히는 문제. separator 색 stroke 으로 윤곽 확보.
struct DozyAuthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline).fontWeight(.medium)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// "이메일로 계속하기" — 브랜드 컬러 outline 스타일.
struct DozyAuthAccentOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline).fontWeight(.medium)
            .foregroundStyle(DozyColor.Brand.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DozyColor.Brand.primary, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
