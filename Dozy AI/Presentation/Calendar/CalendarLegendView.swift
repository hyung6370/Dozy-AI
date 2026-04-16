//
//  CalendarLegendView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

struct CalendarLegendView: View {

    @Environment(\.dismiss) private var dismiss

    private let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, Color(hex: "#5B6EFF"), .purple
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("각 플랫폼의 일정은 아래 색상 바로 구분됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    // Google
                    row(name: "Google 캘린더", logo: {
                        AnyView(
                            Image("google")
                                .resizable().scaledToFit()
                        )
                    }, bar: {
                        AnyView(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#B2EBF2").opacity(0.8))
                                .frame(height: 10)
                        )
                    })

                    Divider().padding(.leading, 72)

                    // Apple
                    row(name: "Apple 캘린더", logo: {
                        AnyView(
                            Image(systemName: "apple.logo")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        )
                    }, bar: {
                        AnyView(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#007AFF").opacity(0.8))
                                .frame(height: 10)
                        )
                    })

                    Divider().padding(.leading, 72)

                    // Dozy - 레인보우
                    row(name: "Dozy 캘린더", logo: {
                        AnyView(
                            Image("Dozy-AI-60x60")
                                .resizable().scaledToFit()
                        )
                    }, bar: {
                        AnyView(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: rainbowColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 10)
                        )
                    })
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 12)
            .navigationTitle("캘린더 범례")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func row(name: String, logo: () -> AnyView, bar: () -> AnyView) -> some View {
        HStack(spacing: 14) {
            logo()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                bar()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
