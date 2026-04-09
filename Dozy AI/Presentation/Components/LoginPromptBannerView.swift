//
//  LoginPromptBannerView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/8/26.
//

import SwiftUI

struct LoginPromptTooltipView: View {

    let onTap: () -> Void

    private let tailHeight: CGFloat = 8
    private let tailOffset: CGFloat = 24
    private let tailWidth: CGFloat = 14
    private let cornerRadius: CGFloat = 12

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("데이터를 안전하게 보호하고 싶다면 로그인을 해보세요 :)")
                    .font(.caption)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 3) {
                    Text("로그인")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.indigo)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .padding(.top, tailHeight)
            .background {
                SpeechBubbleShape(
                    tailOffset: tailOffset,
                    tailWidth: tailWidth,
                    tailHeight: tailHeight,
                    cornerRadius: cornerRadius
                )
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
            .overlay {
                SpeechBubbleShape(
                    tailOffset: tailOffset,
                    tailWidth: tailWidth,
                    tailHeight: tailHeight,
                    cornerRadius: cornerRadius
                )
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Speech Bubble Shape

private struct SpeechBubbleShape: Shape {
    let tailOffset: CGFloat
    let tailWidth: CGFloat
    let tailHeight: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY + tailHeight,
            width: rect.width,
            height: rect.height - tailHeight
        )

        var path = Path(roundedRect: bodyRect, cornerRadius: cornerRadius)

        // Tail triangle pointing upward
        let tailX = rect.minX + tailOffset
        var tail = Path()
        tail.move(to: CGPoint(x: tailX, y: bodyRect.minY))
        tail.addLine(to: CGPoint(x: tailX + tailWidth / 2, y: rect.minY))
        tail.addLine(to: CGPoint(x: tailX + tailWidth, y: bodyRect.minY))
        tail.closeSubpath()

        path.addPath(tail)
        return path
    }
}
