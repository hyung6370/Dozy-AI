//
//  BannerView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/31/26.
//

import SwiftUI

// MARK: - BannerItem Model
struct BannerItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let iconName: String
    let action: (() -> Void)?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        gradientColors: [Color],
        iconName: String,
        action: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.gradientColors = gradientColors
        self.iconName = iconName
        self.action = action
    }
}

// MARK: - 기본 배너 컨텐츠 (광고 적용 전 플레이스홀더)
extension BannerItem {
    static let placeholders: [BannerItem] = [
        BannerItem(
            title: "AI가 하루를 분석합니다",
            subtitle: "일정·할 일·메모를 기반으로 생산성을 측정해요",
            gradientColors: [.blue, .indigo],
            iconName: "brain.head.profile"
        ),
        BannerItem(
            title: "캘린더를 연동해보세요",
            subtitle: "Google · Apple 캘린더를 한 곳에서",
            gradientColors: [.purple, .pink],
            iconName: "calendar.badge.plus"
        ),
        BannerItem(
            title: "Dozy와 함께하는 하루",
            subtitle: "오늘의 할 일을 지금 시작해보세요",
            gradientColors: [.teal, .green],
            iconName: "sparkles"
        ),
    ]
}

// MARK: - BannerView

struct BannerView: View {
    
    let items: [BannerItem]
    var interval: TimeInterval = 4
    
    @State private var currentIndex: Int = 0
    @State private var timer: Timer?
    
    init(items: [BannerItem], interval: TimeInterval = 4) {
        self.items = items
        self.interval = interval
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 페이지 스와이프 영역
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    BannerCard(item: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // 페이지 인디케이터
            HStack(spacing: 5) {
                ForEach(0..<items.count, id: \.self) { index in
                    Capsule()
                        .fill(currentIndex == index ? Color.primary : Color.primary.opacity(0.3))
                        .frame(width: currentIndex == index ? 14 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: currentIndex)
                }
            }
            .padding(.bottom, 10)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: currentIndex) { _ in
            restartTimer()
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                currentIndex = (currentIndex + 1) % items.count
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        stopTimer()
        startTimer()
    }
}

// MARK: - BannerCard (단일 배너 카드)
private struct BannerCard: View {
    
    let item: BannerItem
    
    var body: some View {
        Button {
            item.action?()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(item.gradientColors.first ?? .blue)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
        }
        .buttonStyle(.plain)
    }
}
