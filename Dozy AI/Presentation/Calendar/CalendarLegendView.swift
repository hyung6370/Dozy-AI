//
//  CalendarLegendView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI
import SwiftData

struct CalendarLegendView: View {

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserCategory.order) private var categories: [UserCategory]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("각 플랫폼의 일정은 아래 색상 바로 구분됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    VStack(spacing: 0) {
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
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    if !categories.isEmpty {
                        Text("Dozy 일정은 카테고리별 색상으로 구분됩니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                                if idx > 0 { Divider().padding(.leading, 72) }
                                row(name: cat.name, logo: {
                                    AnyView(Text(cat.emoji).font(.title2))
                                }, bar: {
                                    AnyView(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill((Color(hex: cat.colorHex) ?? .blue).opacity(0.8))
                                            .frame(height: 10)
                                    )
                                })
                            }
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
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
