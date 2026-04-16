//
//  IntroView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

// MARK: - Blob Data

private struct BlobData: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let animDuration: Double
    let animDelay: Double
}

// MARK: - Blob

private struct BlobView: View {
    let blob: BlobData
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
                    scale = CGFloat.random(in: 1.1...1.35)
                    offsetX = CGFloat.random(in: -30...30)
                    offsetY = CGFloat.random(in: -30...30)
                }
            }
    }
}

// MARK: - IntroView

struct IntroView: View {

    let isPrivacy: Bool
    let onFinished: () -> Void
    
    init(isPrivacy: Bool = false, onFinished: @escaping () -> Void) {
        self.isPrivacy = isPrivacy
        self.onFinished = onFinished
    }

    @Environment(\.colorScheme) private var colorScheme

    // Animation states
    @State private var logoVisible = false
    @State private var logoScale: CGFloat = 0.3
    @State private var logoGlow: CGFloat = 0
    @State private var titleVisible = false
    @State private var titleOffset: CGFloat = 30
    @State private var subtitleVisible = false
    @State private var screenOpacity: Double = 1
    @State private var blobs: [BlobData] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // MARK: Background
                (colorScheme == .dark ? Color(hex: "#0D0F1A") : Color(hex: "#EEF0FF"))
                    .ignoresSafeArea()

                // MARK: Blobs
                ForEach(blobs) { blob in
                    BlobView(blob: blob)
                }

                // MARK: Center Content
                VStack(spacing: 24) {
                    // Logo
                    ZStack {
                        // Glow halo
                        Circle()
                            .fill(Color(hex: "#5B6EFF").opacity(0.25))
                            .frame(width: 140, height: 140)
                            .blur(radius: 22)
                            .scaleEffect(1 + logoGlow * 0.15)

                        Image("Dozy-AI-60x60")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 104, height: 104)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoVisible ? 1 : 0)

                    // Text
                    VStack(spacing: 10) {
                        Text("Dozy")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .offset(y: titleOffset)
                            .opacity(titleVisible ? 1 : 0)

                        Text("스마트한 일정 관리의 시작")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .opacity(subtitleVisible ? 1 : 0)
                    }
                }
            }
            .onAppear {
                generateBlobs(in: geo.size)
                if isPrivacy {
                    logoVisible = true
                    logoScale = 1.0
                    titleVisible = true
                    titleOffset = 0
                    subtitleVisible = true
                } else {
                    startSequence()
                }
            }
            .onChange(of: colorScheme) { _, _ in
                generateBlobs(in: geo.size)
            }
        }
        .opacity(screenOpacity)
        .ignoresSafeArea()
    }

    // MARK: - Blob Generation

    private var blobColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: "#4C5FD5").opacity(0.6),
                Color(hex: "#7C5CCC").opacity(0.55),
                Color(hex: "#2D6EBF").opacity(0.5),
                Color(hex: "#B04E8A").opacity(0.45)
            ]
        } else {
            return [
                Color(hex: "#6E82FF").opacity(0.55),
                Color(hex: "#A78BFA").opacity(0.5),
                Color(hex: "#60A5FA").opacity(0.5),
                Color(hex: "#F472B6").opacity(0.4)
            ]
        }
    }

    private func generateBlobs(in size: CGSize) {
        blobs = (0..<8).map { i in
            BlobData(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 260...380),
                color: blobColors[i % blobColors.count],
                animDuration: Double.random(in: 3.0...5.0),
                animDelay: Double.random(in: 0...2.0)
            )
        }
    }

    // MARK: - Animation Sequence

    private func startSequence() {
        // 1. Logo springs in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                logoVisible = true
                logoScale = 1.0
            }
            // Breathing glow
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) {
                logoGlow = 1
            }
        }

        // 2. Title slides up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                titleVisible = true
                titleOffset = 0
            }
        }

        // 3. Subtitle fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                subtitleVisible = true
            }
        }
        
        guard !isPrivacy else { return }

        // 4. Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.6)) {
                screenOpacity = 0
            }
        }

        // 5. Done
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            onFinished()
        }
    }
}
