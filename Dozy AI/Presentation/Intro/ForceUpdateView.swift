//
//  ForceUpdateView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/13/26.
//

import SwiftUI

/// 강제 업데이트 화면.
/// 최소 지원 버전 미달 시 모든 UI 위에 오버레이되어 앱 사용을 차단합니다.
/// 사용자가 App Store로 이동해 업데이트한 후 앱을 재시작할 때까지 해제되지 않습니다.
struct ForceUpdateView: View {

    let appStoreURL: URL

    var body: some View {
        ZStack {
            // 블러 배경
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.orange)
                }

                // 안내 텍스트
                VStack(spacing: 10) {
                    Text("업데이트가 필요합니다")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("현재 버전은 더 이상 지원되지 않습니다.\n최신 버전으로 업데이트해주세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // App Store 버튼
                Button {
                    UIApplication.shared.open(appStoreURL)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app.fill")
                        Text("App Store에서 업데이트")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
            }
            .padding(.horizontal, 24)
        }
    }
}
