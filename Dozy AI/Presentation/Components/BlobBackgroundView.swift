//
//  BlobBackgroundView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//
//  iOS · macOS 공용 ambient 배경 — IntroView 의 blob 무드를 차분하게 다운톤한
//  영구 노출용 버전. light/dark 모드 양쪽에 어울리는 컬러 팔레트로 자동 분기.
//

import SwiftUI

struct BlobBackgroundView: View {

    /// blob 의 알파를 추가로 줄이는 multiplier (0.0~1.0). 기본 1.0.
    /// 가독성이 중요한 화면 위에 깔 때는 0.6 정도로 톤다운 가능.
    var intensity: CGFloat = 1.0

    @Environment(\.colorScheme) private var colorScheme
    @State private var blobs: [BlobItem] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                baseColor.ignoresSafeArea()
                ForEach(blobs) { blob in
                    BlobItemView(blob: blob)
                }
            }
            .onAppear { blobs = generate(in: geo.size) }
            .onChange(of: colorScheme) { _, _ in
                blobs = generate(in: geo.size)
            }
        }
        .ignoresSafeArea()
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? (Color(hex: "#0D0F1A") ?? .black)
            : (Color(hex: "#EEF0FF") ?? .white)
    }

    private var palette: [Color] {
        let alpha = 0.18 * intensity
        let darkAlpha = 0.28 * intensity
        if colorScheme == .dark {
            return [
                (Color(hex: "#4C5FD5") ?? .indigo).opacity(darkAlpha),
                (Color(hex: "#7C5CCC") ?? .purple).opacity(darkAlpha * 0.9),
                (Color(hex: "#2D6EBF") ?? .blue).opacity(darkAlpha * 0.85),
                (Color(hex: "#B04E8A") ?? .pink).opacity(darkAlpha * 0.75)
            ]
        } else {
            return [
                (Color(hex: "#6E82FF") ?? .blue).opacity(alpha),
                (Color(hex: "#A78BFA") ?? .purple).opacity(alpha * 0.9),
                (Color(hex: "#60A5FA") ?? .cyan).opacity(alpha * 0.9),
                (Color(hex: "#F472B6") ?? .pink).opacity(alpha * 0.75)
            ]
        }
    }

    private func generate(in size: CGSize) -> [BlobItem] {
        let colors = palette
        return (0..<6).map { i in
            BlobItem(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 220...340),
                color: colors[i % colors.count],
                animDuration: Double.random(in: 4.0...7.0),
                animDelay: Double.random(in: 0...3.0)
            )
        }
    }
}

// MARK: - BlobItem

private struct BlobItem: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let animDuration: Double
    let animDelay: Double
}

private struct BlobItemView: View {
    let blob: BlobItem
    @State private var scale: CGFloat = 1.0
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    var body: some View {
        Circle()
            .fill(blob.color)
            .frame(width: blob.size, height: blob.size)
            .blur(radius: blob.size * 0.45)
            .scaleEffect(scale)
            .offset(x: offsetX, y: offsetY)
            .position(x: blob.x, y: blob.y)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: blob.animDuration)
                    .repeatForever(autoreverses: true)
                    .delay(blob.animDelay)
                ) {
                    scale = CGFloat.random(in: 1.1...1.3)
                    offsetX = CGFloat.random(in: -25...25)
                    offsetY = CGFloat.random(in: -25...25)
                }
            }
    }
}
