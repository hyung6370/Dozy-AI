//
//  DozyTabBarShape.swift
//  Dozy AI
//
//  탭바 상단에 가운데가 부드럽게 움푹 들어간 노치를 그리는 Shape.
//  가운데 원형 액션 버튼이 노치 안에 안긴 듯한 시각을 만든다.
//

import SwiftUI

struct DozyTabBarShape: Shape {
    /// 가운데 노치의 폭(지름 기준). 가운데 액션 버튼 지름 + 여유 padding.
    var notchDiameter: CGFloat = 72
    /// 노치 깊이(상단으로 얼마나 파고 들어가는지).
    var notchDepth: CGFloat = 28
    /// 노치 양 옆 곡선의 가로 폭(부드럽게 합쳐지는 구간).
    var shoulder: CGFloat = 18
    /// 탭바 좌우 상단 라운드.
    var topCornerRadius: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centerX = rect.midX
        let notchHalfWidth = notchDiameter / 2
        let leftNotchEdge = centerX - notchHalfWidth
        let rightNotchEdge = centerX + notchHalfWidth

        // 시작: 왼쪽 상단(라운드 시작 직전).
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + topCornerRadius))
        if topCornerRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }

        // 상단 라인: 좌측 → 노치 왼쪽 어깨 직전.
        path.addLine(to: CGPoint(x: leftNotchEdge - shoulder, y: rect.minY))

        // 노치 진입: 왼쪽 어깨 곡선 — 살짝 위로 솟는 게 아니라 아래로 휘어들어가게.
        path.addQuadCurve(
            to: CGPoint(x: leftNotchEdge, y: rect.minY + notchDepth * 0.35),
            control: CGPoint(x: leftNotchEdge - shoulder / 2, y: rect.minY)
        )

        // 노치 본체: 가운데 부분 원호.
        path.addQuadCurve(
            to: CGPoint(x: rightNotchEdge, y: rect.minY + notchDepth * 0.35),
            control: CGPoint(x: centerX, y: rect.minY + notchDepth * 1.5)
        )

        // 노치 빠져나오기: 오른쪽 어깨 곡선.
        path.addQuadCurve(
            to: CGPoint(x: rightNotchEdge + shoulder, y: rect.minY),
            control: CGPoint(x: rightNotchEdge + shoulder / 2, y: rect.minY)
        )

        // 상단 라인: 노치 오른쪽 어깨 → 오른쪽 상단 라운드 직전.
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY))
        if topCornerRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + topCornerRadius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
        }

        // 우측 → 하단 → 좌측으로 닫기.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

#if DEBUG
#Preview("Shape") {
    ZStack {
        DozyColor.Background.grouped.ignoresSafeArea()
        DozyTabBarShape()
            .fill(DozyColor.Background.primary)
            .frame(height: 80)
            .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
            .padding(.bottom, 40)
    }
}
#endif
