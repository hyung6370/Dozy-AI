//
//  LoginPromptBannerView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

/// 홈 탭 비로그인 상태 안내 카드.
/// 바로 위의 "Dozy 일정 요약" 카드와 같은 카드 언어(.regularMaterial + 14pt 라운드 + 테마 보더)를 쓴다.
struct LoginPromptCardView: View {

    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(symbol: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(DozyColor.Brand.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("로그인 · 회원가입")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("로그인하면 모든 기기에서 데이터가 안전하게 백업돼요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("로그인")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DozyColor.Brand.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DozyColor.Brand.primary.opacity(0.12), in: Capsule())
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .dozyThemedCardBorder(cornerRadius: 14)
            // 텍스트/아이콘만이 아니라 카드 전체(빈 영역·가장자리 포함)가 탭 되도록.
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        LoginPromptCardView {}
    }
    .padding()
}
