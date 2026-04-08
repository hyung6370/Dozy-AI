//
//  IntroView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

// MARK: - Star Data

private struct StarData: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let animDuration: Double
    let animDelay: Double
}

// MARK: - Star Particle

private struct StarParticle: View {
    let star: StarData
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: star.size, height: star.size)
            .opacity(opacity)
            .position(x: star.x, y: star.y)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: star.animDuration)
                    .repeatForever(autoreverses: true)
                    .delay(star.animDelay)
                ) {
                    opacity = Double.random(in: 0.5...1.0)
                }
            }
    }
}

// MARK: - IntroView

struct IntroView: View {

    let onFinished: () -> Void

    // Animation states
    @State private var logoVisible = false
    @State private var logoScale: CGFloat = 0.3
    @State private var logoGlow: CGFloat = 0
    @State private var titleVisible = false
    @State private var titleOffset: CGFloat = 30
    @State private var subtitleVisible = false
    @State private var screenOpacity: Double = 1
    @State private var stars: [StarData] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // MARK: Background
                LinearGradient(
                    colors: [
                        Color(hex: "#080C1A"),
                        Color(hex: "#131838")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // MARK: Stars
                ForEach(stars) { star in
                    StarParticle(star: star)
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
                            .shadow(color: Color(hex: "#5B6EFF").opacity(0.55), radius: 20)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoVisible ? 1 : 0)

                    // Text
                    VStack(spacing: 10) {
                        Text("Dozy")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .offset(y: titleOffset)
                            .opacity(titleVisible ? 1 : 0)

                        Text("스마트한 일정 관리의 시작")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .opacity(subtitleVisible ? 1 : 0)
                    }
                }
            }
            .onAppear {
                generateStars(in: geo.size)
                startSequence()
            }
        }
        .opacity(screenOpacity)
        .ignoresSafeArea()
    }

    // MARK: - Star Generation

    private func generateStars(in size: CGSize) {
        stars = (0..<30).map { _ in
            StarData(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height * 0.8),
                size: CGFloat.random(in: 1.5...4.5),
                animDuration: Double.random(in: 1.0...2.2),
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
