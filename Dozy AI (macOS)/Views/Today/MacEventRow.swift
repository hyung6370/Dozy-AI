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
        // 배경 테마 (system / ambientMesh / blob) 에 맞춰 머티리얼 + 색조 + 외곽
        // stroke 가 함께 갈아끼는 공통 modifier. controlBackgroundColor 직접 사용
        // 시 ambient/blob 의 컬러풀한 배경 위에 카드가 떠 보이는 문제 해소.
        .themedCardSurface(cornerRadius: 10)
        // 카테고리 accent 외곽선은 카드 surface 위에 추가로 얹어 일정의 색상 컨텍스트
        // 유지. 완료 상태에선 stroke 도 같이 dim.
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accent.opacity(isCompleted ? 0 : 0.12), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.6 : 1.0)
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
                    MacEventSourceIcon(source: event.source, size: 13)
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

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            if event.isShared {
                Image(systemName: "person.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(accent)
                    .help("공유 캘린더 일정")
            }
        }
        .contentShape(Rectangle())
    }
}
