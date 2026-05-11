//
//  DozyBottomSheet.swift
//  Dozy AI
//
//  커스텀 바텀 시트.
//  - SwiftUI 의 .sheet 와 달리 ZStack overlay 라서 외부에서 layer 순서를 제어할 수 있다.
//    (예: MainTabView 에서 탭바를 시트 위 layer 로 두어 "탭바 뒤에서 슬라이드 업" 효과)
//  - dismiss 트리거 3가지: swipe-down drag / dim 탭 / 시트 내부 콘텐츠가 부르는 onDismiss.
//

import SwiftUI

struct DozyBottomSheet<Content: View>: View {

    @Binding var isPresented: Bool
    /// 시트가 화면 bottom 에서 멈추는 안쪽 여백. 탭바 같은 항상 보여야 하는 UI 의 height 를 넘긴다.
    var bottomInset: CGFloat
    /// 시트 상단 라운드 코너.
    var cornerRadius: CGFloat = 20
    /// 시트의 top padding. 화면 위쪽에서 시트가 시작할 위치.
    var topInset: CGFloat = 60
    /// dismiss 가 발생하면 호출. (드래그/탭/저장 등 어떤 경로든)
    var onDismiss: (() -> Void)? = nil

    @ViewBuilder var content: () -> Content

    @State private var dragOffset: CGFloat = 0

    /// 이 값을 넘으면 dismiss 로 처리한다 (시트 height 일부 비율).
    private let dragDismissThreshold: CGFloat = 120
    /// 위로 드래그할 때 살짝 따라가지만 저항을 준다.
    private let upwardResistance: CGFloat = 0.25

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                // Invisible hit area — dim 색은 없애되 시트 외부 탭 dismiss 는 유지.
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .zIndex(0)

                // Sheet body — 배경색 통일 (Form 의 systemGroupedBackground 와 동일).
                VStack(spacing: 0) {
                    dragHandle
                    content()
                }
                .background(DozyColor.Background.grouped)
                .clipShape(.rect(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius))
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
                .offset(y: dragOffset)
                .gesture(dragGesture)
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isPresented)
        .onChange(of: isPresented) { _, newValue in
            // 외부에서 isPresented = false 로 닫히는 경우(예: 탭바 가운데 버튼 toggle)
            // dragOffset 이 누적되어 있을 수 있으니 reset.
            if !newValue { dragOffset = 0 }
        }
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        Capsule()
            .fill(DozyColor.Text.tertiary.opacity(0.45))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .background(DozyColor.Background.grouped)
            .contentShape(Rectangle())
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height >= 0 {
                    dragOffset = value.translation.height
                } else {
                    dragOffset = value.translation.height * upwardResistance
                }
            }
            .onEnded { value in
                if value.translation.height > dragDismissThreshold {
                    close()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isPresented = false
            dragOffset = 0
        }
        onDismiss?()
    }
}

// MARK: - Preview

#if DEBUG
private struct DozyBottomSheetPreviewHost: View {
    @State private var show = false
    var body: some View {
        ZStack {
            DozyColor.Background.grouped.ignoresSafeArea()
            Button("Show sheet") { show = true }
                .font(DozyFont.headline)

            DozyBottomSheet(isPresented: $show, bottomInset: 84) {
                VStack(spacing: DozySpacing.md) {
                    Text("시트 내용")
                        .font(DozyFont.title2)
                    Text("드래그로 닫기 / dim 탭 / 시트 안에서 isPresented = false")
                        .font(DozyFont.subheadline)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(DozySpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview("Light") {
    DozyBottomSheetPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DozyBottomSheetPreviewHost()
        .preferredColorScheme(.dark)
}
#endif
