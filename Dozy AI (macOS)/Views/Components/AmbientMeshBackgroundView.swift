//
//  AmbientMeshBackgroundView.swift
//  Dozy AI (macOS)
//
//  Option 2 — 저채도 MeshGradient ambient 배경. BlobBackgroundView 의 쿨 라벤더 ↔
//  네이비 무드를 유지하면서 원형 얼룩을 없앤 차분한 변주. macOS 15+ 전용.
//

import SwiftUI

struct AmbientMeshBackgroundView: View {

    /// 0.0 = 베이스 평면색, 1.0 = 팔레트 그대로. 기본 1.0.
    var intensity: CGFloat = 1.0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseColor
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
        }
        .ignoresSafeArea()
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? (Color(hex: "#0E1018") ?? .black)
            : (Color(hex: "#EFF1FA") ?? .white)
    }

    private var palette: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: "#0E1018") ?? .black,
                Color(hex: "#11132A") ?? .black,
                Color(hex: "#13112B") ?? .black,
                Color(hex: "#10162A") ?? .black,
                Color(hex: "#181B36") ?? .black,
                Color(hex: "#1A1830") ?? .black,
                Color(hex: "#0F1422") ?? .black,
                Color(hex: "#11142A") ?? .black,
                Color(hex: "#14111F") ?? .black
            ]
        } else {
            return [
                Color(hex: "#F0F1FB") ?? .white,
                Color(hex: "#E9EAF6") ?? .white,
                Color(hex: "#ECE7F3") ?? .white,
                Color(hex: "#E8EAF6") ?? .white,
                Color(hex: "#EDEEFA") ?? .white,
                Color(hex: "#EAE6F2") ?? .white,
                Color(hex: "#DCE0F0") ?? .white,
                Color(hex: "#E1E4F2") ?? .white,
                Color(hex: "#E5E0EC") ?? .white
            ]
        }
    }
}
