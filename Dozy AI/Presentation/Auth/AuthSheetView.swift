//
//  AuthSheetView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 7/2/26.
//

import SwiftUI

/// 아래에서 올라오는 로그인 시트.
///
/// 시스템 .sheet 대신 DragGesture 로 직접 구현 — 세 개의 offset 을 역할별로
/// 분리해 "밀어 올려 여는 시트" 를 만든다:
/// - `startOffsetY`      시트의 처음 위치 (medium — 화면 절반쯤 걸친 상태)
/// - `currentDragOffsetY` 지금 드래그 중인 실시간 이동량
/// - `endingOffsetY`     드래그가 끝난 뒤 확정된 위치 (0 = medium, -startOffsetY = 펼침)
///
/// 세 값을 모두 .offset(y:) 으로 더해 최종 위치가 결정되고, onEnded 의
/// 임계값(threshold) 분기로 펼침/접힘/닫힘이 스냅된다.
struct AuthSheetView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var isPresented: Bool

    /// 지금 드래그하는 순간의 이동량 (실시간).
    @State private var currentDragOffsetY: CGFloat = 0
    /// 드래그를 끝냈을 때 확정되는 최종 위치.
    @State private var endingOffsetY: CGFloat = 0
    /// "이메일로 계속하기" 를 눌러 이메일 폼이 펼쳐졌는지.
    @State private var showEmailForm = false

    /// 클램프/스냅 규칙 — 순수 로직으로 분리해 단위 테스트 대상.
    /// threshold 150 = "이 정도는 끌어야 열리고/닫힌다". 조절하면 민감도가 바뀐다.
    private let dragLogic = AuthSheetDragLogic(dragThreshold: 150)
    /// 스냅 스프링이 오버슈트해 시트가 잠깐 바닥보다 위로 떠도 하단에 빈틈이
    /// 보이지 않도록 배경을 아래로 연장해 두는 여분.
    private let overshootBuffer: CGFloat = 200
    /// 시트 전체 높이 = 컨테이너의 92%.
    private let sheetHeightRatio: CGFloat = 0.92
    /// medium 시작 위치 = 컨테이너의 42% 만큼 아래로 밀어둠 (보이는 부분 ≈ 50%).
    private let startOffsetRatio: CGFloat = 0.42

    var body: some View {
        // 블로그 예제의 UIScreen.main.bounds 대신 GeometryReader —
        // 탭바/키보드로 가용 영역이 변해도 컨테이너 기준으로 따라간다.
        GeometryReader { geo in
            let startOffsetY = geo.size.height * startOffsetRatio
            let sheetHeight = geo.size.height * sheetHeightRatio

            VStack(spacing: 0) {
                dragZone
                    .gesture(sheetDragGesture(startOffsetY: startOffsetY))

                ScrollView {
                    VStack(spacing: 12) {
                        socialButtons

                        HStack(spacing: 8) {
                            Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                            Text("또는")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                        }

                        if showEmailForm {
                            AuthEmailFormView()
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Button {
                                withAnimation(.spring()) { showEmailForm = true }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("이메일로 계속하기")
                                }
                            }
                            .buttonStyle(DozyAuthAccentOutlineButtonStyle())
                        }
                    }
                    .padding(.horizontal, DozySpacing.lg)
                    .padding(.bottom, DozySpacing.xl)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            // 로딩 중에도 폼 (이메일·OTP·비밀번호) 은 그대로 보이게 — 사용자가 지금
            // 어느 단계에서 무엇을 입력했는지 시각적으로 유지.
            .disabled(authViewModel.isLoading)
            .overlay {
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .frame(height: sheetHeight, alignment: .top)
            .frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                    .fill(DozyColor.Background.primary)
                    // 시트가 오버슈트로 떠올라도 탭바와의 사이가 비지 않게
                    // 배경만 아래로 연장.
                    .padding(.bottom, -overshootBuffer)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: -4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            // 세 offset 의 합이 최종 위치.
            .offset(y: startOffsetY)
            .offset(y: currentDragOffsetY)
            .offset(y: endingOffsetY)
            // 이메일 폼 진입 시 자동으로 완전히 펼침 — medium 에선 키보드까지
            // 뜨면 가용 영역이 너무 좁다.
            .onChange(of: showEmailForm) { _, opened in
                if opened {
                    withAnimation(.spring()) { endingOffsetY = -startOffsetY }
                }
            }
            // 키보드가 뜨면 safe area 가 줄어 geo.size.height 가 바뀐다.
            // 펼침 위치는 예전 높이 기준 절대값이라 새 높이로 재스냅.
            .onChange(of: geo.size.height) { _, newHeight in
                if endingOffsetY != 0 {
                    withAnimation(.spring()) {
                        endingOffsetY = -(newHeight * startOffsetRatio)
                    }
                }
            }
        }
        // 시트가 닫힐 때 VM 에 남은 OTP 흐름/오류 정리 — 입력값 @State 는 뷰와
        // 함께 소멸하지만 VM 상태는 살아남아 다음에 열 때 단계가 꼬일 수 있다.
        .onDisappear {
            authViewModel.cancelEmailOTPFlow()
            authViewModel.cancelPasswordResetFlow()
            authViewModel.errorMessage = nil
        }
    }

    // MARK: - Drag

    /// 그래버 + 브랜딩 헤더 — DragGesture 부착 영역.
    /// 시트 전체에 붙이면 아래 ScrollView 의 스크롤과 제스처가 충돌해서
    /// 헤더 영역에만 붙인다.
    private var dragZone: some View {
        VStack(spacing: DozySpacing.sm) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 38, height: 5)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Image("Dozy-AI-60x60")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Dozy 시작하기")
                    .font(.title3).fontWeight(.bold)

                Text("로그인하면 모든 기기에서 데이터가 안전하게 백업돼요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, DozySpacing.md)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func sheetDragGesture(startOffsetY: CGFloat) -> some Gesture {
        // 기본 좌표계(.local)는 제스처가 붙은 뷰 자신의 좌표계라서, offset 으로
        // 뷰가 움직이면 좌표계도 같이 움직여 translation 이 매 프레임 재계산되는
        // 피드백 루프(미세 진동)가 생긴다. 움직이지 않는 .global 에서 측정.
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                // 드래그 "도중" 은 애니메이션 없이 즉시 반영 — 매 프레임 스프링을
                // 리타게팅하면 손가락보다 늦게 따라오고, 목표에 도달할 때 관성으로
                // 오버슈트해 시트가 바닥보다 위로 떠 버린다. 스프링은 손을 뗀 뒤
                // 스냅(onEnded)에만 쓴다.
                currentDragOffsetY = dragLogic.clampedDragOffset(
                    translation: value.translation.height,
                    startOffsetY: startOffsetY,
                    endingOffsetY: endingOffsetY
                )
            }
            .onEnded { _ in
                let action = dragLogic.endAction(
                    currentDragOffsetY: currentDragOffsetY,
                    endingOffsetY: endingOffsetY,
                    isLoading: authViewModel.isLoading
                )
                withAnimation(.spring()) {
                    switch action {
                    case .expand:   endingOffsetY = -startOffsetY
                    case .collapse: endingOffsetY = 0
                    case .dismiss:  isPresented = false
                    case .stay:     break
                    }
                    // 실시간 값은 항상 리셋 — start + ending 만으로 위치가 결정되게.
                    currentDragOffsetY = 0
                }
            }
    }

    // MARK: - Social Buttons

    /// Apple 로그인 (DEBUG 개발 환경에서는 미지원 — dev 는 Email 로 우회).
    private var isAppleSignInAvailable: Bool {
        #if DEBUG
        return AppEnvironment.current != .development
        #else
        return true
        #endif
    }

    @ViewBuilder
    private var socialButtons: some View {
        if isAppleSignInAvailable {
            Button { authViewModel.signInWithApple() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .medium))
                    Text("Apple로 로그인")
                }
            }
            .buttonStyle(DozyAuthPrimaryButtonStyle())
        }

        Button { authViewModel.signInWithGoogle() } label: {
            HStack(spacing: 10) {
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Google로 로그인")
            }
        }
        .buttonStyle(DozyAuthSecondaryButtonStyle())
    }
}
