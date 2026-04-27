//
//  MacEventRow.swift
//  Dozy AI (macOS)
//
//  iOS EventRow 와 같은 시각 언어를 따르되 공유 캘린더 파트너 태그 / 외부 미러 등
//  macOS 에서 아직 지원하지 않는 요소는 생략한 단순화 버전.
//
//  hit-test 는 두 형제 Button 으로 분할 — 체크 아이콘 영역 / 본문 영역. nested Button
//  이나 부모 .onTapGesture 로 감싸면 macOS SwiftUI 가 자식 Button 클릭을 안정적으로
//  라우팅하지 못해서 토글이 가끔 무시된다.
//

import SwiftUI

struct MacEventRow: View {
    let event: CalendarEvent
    var isCompleted: Bool = false
    /// 체크 아이콘 탭 시 호출. nil 이면 체크 영역은 시각적 표시만, 인터랙션 비활성.
    var onToggleCompletion: (() -> Void)? = nil
    /// 본문(체크 외 영역) 탭 시 호출. 예: 일정 상세 모달 띄우기. nil 이면 본문 영역은 비활성.
    var onSelect: (() -> Void)? = nil

    var body: some View {
        let accent = Color(hex: event.calendarColorHex) ?? .blue
        return HStack(spacing: 14) {
            // 좌측: 완료 체크 — 자체 Button.
            Button {
                onToggleCompletion?()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isCompleted ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onToggleCompletion == nil)

            // 본문(컬러 바 + 텍스트) — 또 다른 Button. 위와 형제 관계라 hit-test 충돌 없음.
            Button {
                onSelect?()
            } label: {
                bodyContent(accent: accent)
            }
            .buttonStyle(.plain)
            .disabled(onSelect == nil)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isCompleted ? 0.5 : 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accent.opacity(isCompleted ? 0 : 0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func bodyContent(accent: Color) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.source == .dozy ? accent.opacity(0.5) : accent)
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    if event.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(accent)
                    }
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .strikethrough(isCompleted, color: .secondary)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                }

                HStack(spacing: 10) {
                    Text(event.timeRangeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if event.isShared {
                        Label("공유", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(accent)
                    }

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
