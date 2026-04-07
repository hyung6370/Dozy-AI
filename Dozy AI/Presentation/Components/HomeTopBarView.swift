//
//  HomeTopBarView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import SwiftUI

struct HomeTopBarView: View {

    let hasNotification: Bool
    let onNotificationTap: () -> Void
    let onProfileTap: () -> Void

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: Date())
    }

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
                Button { onNotificationTap() } label: {
                    Image(hasNotification ? "notifications_active" : "notifications_none")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }

                Button { onProfileTap() } label: {
                    Image("person_outline")
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
