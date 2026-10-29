//
//  SharedCalendarComponents.swift
//  Dozy AI
//
//  공유 캘린더 화면 공용 컴포넌트 (#129). 목록 · 상세 · 만들기 · 참여 · 설정이 같은 모양을 쓰도록 모았다.
//  - 커버: 대표 이미지, 없으면 브랜드 그라데이션 타일
//  - 멤버 아바타: 닉네임 첫 글자 + userID 로 고정되는 색 (기기 · 화면이 바뀌어도 같은 사람은 같은 색)
//  - 초대 코드 카드: 복사 · 공유 · 새 코드 발급 · 만료 표시
//  - 버튼 스타일: 브랜드 채움 / 브랜드 옅은 배경
//

import SwiftUI
import Kingfisher

// MARK: - 커버

struct SharedCalendarCover: View {
    let imageURL: URL?
    var size: CGFloat = 52
    var cornerRadius: CGFloat = DozyRadius.md

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(
                colors: [DozyColor.Brand.primary, DozyColor.Brand.secondary],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            Image(symbol: "person.2.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
            if let imageURL {
                KFImage(imageURL)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: size * 3, height: size * 3)))
                    .cacheOriginalImage()
                    .fade(duration: 0.15)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }
}

// MARK: - 멤버 아바타

struct SharedMemberAvatar: View {
    let name: String
    /// 색을 고정하는 값 — userID
    let seed: String
    var size: CGFloat = 36
    var isOwner = false

    private static let palette: [Color] = [
        DozyColor.Brand.primary, DozyColor.Brand.secondary,
        Color(.sRGB, red: 0.95, green: 0.45, blue: 0.55, opacity: 1),   // 코랄 핑크
        Color(.sRGB, red: 0.20, green: 0.70, blue: 0.62, opacity: 1),   // 틸
        Color(.sRGB, red: 0.98, green: 0.62, blue: 0.20, opacity: 1),   // 오렌지
        Color(.sRGB, red: 0.30, green: 0.62, blue: 0.95, opacity: 1),   // 스카이
    ]

    static func color(for seed: String) -> Color {
        let sum = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(sum) % palette.count]
    }

    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        let tint = Self.color(for: seed)
        ZStack {
            Circle().fill(tint.opacity(0.18))
            Text(initial)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if isOwner {
                Image(symbol: "crown.fill")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(DozyColor.State.warning)
                    .padding(size * 0.06)
                    .background(DozyColor.Background.groupedRow, in: Circle())
                    .offset(x: size * 0.12, y: -size * 0.12)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 겹친 아바타 묶음 — 최대 `limit` 명, 넘치면 "+N"
struct SharedMemberAvatarStack: View {
    struct Item: Identifiable {
        let id: String
        let name: String
    }

    let items: [Item]
    var size: CGFloat = 26
    var limit = 4

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(items.prefix(limit)) { item in
                SharedMemberAvatar(name: item.name, seed: item.id, size: size)
                    .background(Circle().fill(DozyColor.Background.groupedRow))
                    .overlay(Circle().strokeBorder(DozyColor.Background.groupedRow, lineWidth: 2))
            }
            if items.count > limit {
                Text("+\(items.count - limit)")
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(DozyColor.Text.secondary)
                    .frame(width: size, height: size)
                    .background(Circle().fill(DozyColor.Background.grouped))
                    .overlay(Circle().strokeBorder(DozyColor.Background.groupedRow, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

extension SharedCalendarMember {
    /// 화면에 보일 이름 — 닉네임, 없으면 "나" / "파트너"
    func displayName(currentUserID: String) -> String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
        return userID == currentUserID ? String(localized: "나") : String(localized: "파트너")
    }
}

// MARK: - 초대 코드 카드

struct SharedInviteCodeCard: View {
    let code: String
    let expiresAt: Date?
    /// 소유자만 — nil 이면 "새 코드 발급" 숨김
    var onRegenerate: (() -> Void)? = nil

    @State private var copied = false

    private var isExpired: Bool { expiresAt.map { $0 < Date() } ?? false }

    var body: some View {
        VStack(spacing: DozySpacing.md) {
            Text(code)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .tracking(8)
                .foregroundStyle(isExpired ? DozyColor.Text.tertiary : DozyColor.Brand.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .textSelection(.enabled)
                .accessibilityLabel(Text("초대 코드 \(code.map(String.init).joined(separator: " "))"))

            if isExpired {
                Label("코드가 만료됐어요", symbol: "clock")
                    .font(DozyFont.captionEmphasized)
                    .foregroundStyle(DozyColor.State.warning)
            } else if let expiresAt {
                Text("만료 \(expiresAt.formatted(.dateTime.month().day().hour().minute()))")
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
            }

            HStack(spacing: DozySpacing.sm) {
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Label(copied ? "복사됨" : "복사", symbol: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(SharedCalendarSecondaryButtonStyle())
                .animation(.easeInOut(duration: 0.2), value: copied)

                ShareLink(item: sharedCalendarInviteText(code: code), subject: Text("Dozy AI 공유 캘린더 초대")) {
                    Label("공유하기", symbol: "square.and.arrow.up")
                }
                .buttonStyle(SharedCalendarPrimaryButtonStyle())
                .disabled(isExpired)
            }

            if let onRegenerate {
                Button(action: onRegenerate) {
                    Label("새 코드 발급", symbol: "arrow.clockwise")
                        .font(DozyFont.subheadlineEmphasized)
                        .foregroundStyle(isExpired ? DozyColor.Brand.primary : DozyColor.Text.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DozySpacing.lg)
        .padding(.horizontal, DozySpacing.md)
        .dozyThemedCardSurface(cornerRadius: DozyRadius.lg)
    }
}

func sharedCalendarInviteText(code: String) -> String {
    String(localized: "Dozy AI 공유 캘린더에 초대됐어요! 📅\n코드: \(code)\n\n앱에서 '초대 코드로 참여하기'를 눌러 입력하세요.")
}

// MARK: - 버튼 스타일

/// 브랜드 채움 — 주요 동작 (만들기 · 참여하기 · 공유하기)
struct SharedCalendarPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DozyFont.subheadlineEmphasized)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isEnabled ? DozyColor.Brand.primary : Color(.systemGray4),
                in: RoundedRectangle(cornerRadius: DozyRadius.md, style: .continuous)
            )
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// 브랜드 옅은 배경 — 보조 동작 (복사 · 초대 코드로 참여)
struct SharedCalendarSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DozyFont.subheadlineEmphasized)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                DozyColor.Brand.primary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: DozyRadius.md, style: .continuous)
            )
            .foregroundStyle(DozyColor.Brand.primary)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - 헤더 일러스트

/// 만들기 · 참여 · 빈 상태 위쪽 — 브랜드 타일 안에 아이콘
struct SharedCalendarHeaderIcon: View {
    let symbol: String
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(
                    colors: [DozyColor.Brand.primary, DozyColor.Brand.secondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: DozyColor.Brand.primary.opacity(0.3), radius: 12, y: 6)
            Image(symbol: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
