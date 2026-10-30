//
//  DozyToast.swift
//  Dozy AI
//
//  화면 하단 토스트 (#143). 일정 수정 · 삭제처럼 "됐다 / 안 됐다"만 알리면 되는 결과를 확인 버튼 없이 보여 준다.
//  - 아이콘 + 한 줄 문구 캡슐, 플로팅 탭바 위에 뜬다 (위치는 호출하는 쪽이 bottomInset 으로 정한다)
//  - 2초 뒤 자동으로 사라지고, 탭하면 바로 닫힌다. 성공 · 실패 햅틱, VoiceOver 안내
//  - 같은 문구가 연달아 와도 id 가 달라 다시 뜨고 타이머가 새로 시작된다
//

import SwiftUI

struct DozyToast: Identifiable, Equatable {
    enum Style: Equatable {
        case success
        case failure
    }

    let id = UUID()
    let style: Style
    let message: String

    static func success(_ message: String) -> DozyToast { DozyToast(style: .success, message: message) }
    static func failure(_ message: String) -> DozyToast { DozyToast(style: .failure, message: message) }

    /// 화면에 머무는 시간
    static let displayDuration: Duration = .seconds(2)
}

// MARK: - 일정 결과 문구

extension DozyToast {
    static var eventUpdated: DozyToast { .success(String(localized: "일정을 수정했어요")) }
    static var eventUpdateFailed: DozyToast { .failure(String(localized: "일정을 저장하지 못했어요")) }
    static var eventDeleted: DozyToast { .success(String(localized: "일정을 삭제했어요")) }
    static var eventDeleteFailed: DozyToast { .failure(String(localized: "일정을 삭제하지 못했어요")) }
    static var occurrenceDeleted: DozyToast { .success(String(localized: "이 일정만 삭제했어요")) }
    static var futureOccurrencesDeleted: DozyToast { .success(String(localized: "이후 일정을 삭제했어요")) }
    static var displaySettingsSaved: DozyToast { .success(String(localized: "표시 설정을 저장했어요")) }
}

// MARK: - View

struct DozyToastView: View {
    let toast: DozyToast

    var body: some View {
        HStack(spacing: DozySpacing.xs) {
            Image(symbol: toast.style == .success ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(toast.style == .success ? DozyColor.State.success : DozyColor.State.danger)
            Text(toast.message)
                .font(DozyFont.subheadlineEmphasized)
                .foregroundStyle(DozyColor.Text.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, DozySpacing.md)
        .padding(.vertical, DozySpacing.sm)
        .dozyGlassSurface(in: Capsule(), style: .regular)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Modifier

extension View {
    /// `toast` 에 값을 넣으면 하단에 띄우고 2초 뒤 nil 로 되돌린다.
    /// - bottomInset: 화면 아래에서 띄울 거리. 탭 화면은 `DozyTabBarMetrics.scrollClearance` (탭바 위).
    func dozyToast(_ toast: Binding<DozyToast?>, bottomInset: CGFloat = DozySpacing.lg) -> some View {
        modifier(DozyToastModifier(toast: toast, bottomInset: bottomInset))
    }
}

private struct DozyToastModifier: ViewModifier {
    @Binding var toast: DozyToast?
    let bottomInset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast {
                    DozyToastView(toast: toast)
                        .padding(.horizontal, DozySpacing.lg)
                        .padding(.bottom, bottomInset)
                        .onTapGesture { self.toast = nil }
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.85), value: toast?.id)
            .sensoryFeedback(trigger: toast?.id) { _, newID in
                guard newID != nil, let toast else { return nil }
                return toast.style == .success ? .success : .error
            }
            .task(id: toast?.id) {
                guard let current = toast else { return }
                AccessibilityNotification.Announcement(current.message).post()
                try? await Task.sleep(for: DozyToast.displayDuration)
                guard !Task.isCancelled, toast?.id == current.id else { return }
                toast = nil
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        DozyToastView(toast: .eventUpdated)
        DozyToastView(toast: .eventDeleteFailed)
    }
    .padding()
}
