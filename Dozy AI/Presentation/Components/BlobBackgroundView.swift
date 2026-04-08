//
//  BlobBackgroundView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

struct BlobBackgroundView: View {

    @State private var blobs: [BlobItem] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "#EEF0FF")
                    .ignoresSafeArea()

                ForEach(blobs) { blob in
                    BlobItemView(blob: blob)
                }
            }
            .onAppear {
                blobs = Self.generate(in: geo.size)
            }
        }
        .ignoresSafeArea()
    }

    private static let colors: [Color] = [
        Color(hex: "#6E82FF").opacity(0.2),
        Color(hex: "#A78BFA").opacity(0.18),
        Color(hex: "#60A5FA").opacity(0.18),
        Color(hex: "#F472B6").opacity(0.14)
    ]

    private static func generate(in size: CGSize) -> [BlobItem] {
        (0..<6).map { i in
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
