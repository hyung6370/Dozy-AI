//
//  HomeTopBarView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import SwiftUI

struct HomeTopBarView: View {

    let hasNotification: Bool
    /// 로그아웃 상태에서는 공유 캘린더 진입 아이콘을 숨긴다.
    let isLoggedIn: Bool
    let onSharedCalendarTap: () -> Void
    let onNotificationTap: () -> Void
    let onProfileTap: () -> Void

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: Date())
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image("Dozy-AI-20x20")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)

                Text(todayString)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            HStack(spacing: 16) {
                if isLoggedIn {
                    Button { onSharedCalendarTap() } label: {
                        Image(colorScheme == .dark ? "Dark-Home-Share-Calendar" : "Light-Home-Share-Calendar")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    }
                }

                Button { onNotificationTap() } label: {
                    Image(hasNotification
                        ? (colorScheme == .dark ? "Dark-Bell-on" : "Light-Bell-on")
                        : (colorScheme == .dark ? "Dark-Bell-non" : "Light-Bell-non")
                    )
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }

                Button { onProfileTap() } label: {
                    Image(colorScheme == .dark ? "Dark-User" : "Light-User")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}
