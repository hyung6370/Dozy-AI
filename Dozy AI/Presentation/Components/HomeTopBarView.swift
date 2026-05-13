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

    @AppStorage(DozyBackgroundTheme.storageKey)
    private var themeRaw: String = DozyBackgroundTheme.defaultTheme.rawValue

    private var theme: DozyBackgroundTheme {
        DozyBackgroundTheme(rawValue: themeRaw) ?? .defaultTheme
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = String(localized: "M월 d일 EEEE")
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
        .background(topBarBackground)
    }

    @ViewBuilder
    private var topBarBackground: some View {
        if theme == .system {
            // 기본 테마는 원래대로 systemBackground.
            Color(.systemBackground)
        } else {
            // ambient/blob: 투명 — themed shell bg 가 상단바 영역까지 자연스럽게 이어진다.
            Color.clear
        }
    }
}
