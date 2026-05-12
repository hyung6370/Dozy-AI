//
//  AmbientMeshBackgroundView.swift
//  Dozy AI
//
//  저채도 MeshGradient ambient 배경. macOS 의 동명 컴포넌트와 동일한 팔레트.
//  iOS 17+ MeshGradient 지원 (iOS 18.0+).
//

import SwiftUI

struct AmbientMeshBackgroundView: View {

    /// 0.0 = 베이스 평면색, 1.0 = 팔레트 그대로. 기본 1.0.
    var intensity: CGFloat = 1.0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseColor
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: palette
                )
                .opacity(min(max(intensity, 0), 1))
            } else {
                // iOS 17 fallback — LinearGradient 로 비슷한 톤.
                LinearGradient(
                    colors: [palette.first ?? baseColor, palette.last ?? baseColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(min(max(intensity, 0), 1))
            }
        }
        .ignoresSafeArea()
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? (Color(hex: "#0E1018"))
            : (Color(hex: "#EFF1FA"))
    }

    private var palette: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: "#0E1018"),
                Color(hex: "#11132A"),
                Color(hex: "#13112B"),
                Color(hex: "#10162A"),
                Color(hex: "#181B36"),
                Color(hex: "#1A1830"),
                Color(hex: "#0F1422"),
                Color(hex: "#11142A"),
                Color(hex: "#14111F")
            ]
        } else {
            return [
                Color(hex: "#F0F1FB"),
                Color(hex: "#E9EAF6"),
                Color(hex: "#ECE7F3"),
                Color(hex: "#E8EAF6"),
                Color(hex: "#EDEEFA"),
                Color(hex: "#EAE6F2"),
                Color(hex: "#DCE0F0"),
                Color(hex: "#E1E4F2"),
                Color(hex: "#E5E0EC")
            ]
        }
    }
}
