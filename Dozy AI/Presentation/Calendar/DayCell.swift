//
//  DayCell.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI

struct DayCell: View {

    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let eventBars: [EventBarInfo]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(verbatim: "\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle((isSelected || isToday) ? .white : .primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(isSelected ? Color.blue : isToday ? Color.orange : Color.clear))

                VStack(spacing: 2) {
                    ForEach(eventBars.prefix(3)) { bar in
                        EventBarView(bar: bar)
                    }
                    // 빈 슬롯 유지 (셀 높이 고정)
                    ForEach(0..<max(0, 3 - min(eventBars.count, 3)), id: \.self) { _ in
                        Color.clear.frame(height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - EventBarView

/// 주 뷰 / DayCell 의 이벤트 표식 — pill 스타일 (단일/시작은 제목 텍스트 포함, 가운데/끝은 연결 바).
/// MonthWeekRowView 의 `EventPill` 과 같은 톤(opacity 0.75 / Dozy 는 0.2 배경)을 공유.
struct EventBarView: View {

    let bar: EventBarInfo
    @Environment(\.colorScheme) private var colorScheme

    /// 카테고리 색 (다크모드에서 너무 어두우면 자동으로 살짝 끌어올림 — fill 용 보수적 보정).
    private var color: Color {
        (Color(hex: bar.colorHex) ?? .blue).eventDisplayColor(in: colorScheme)
    }
    /// Dozy 일정 텍스트에 쓰는 색 — fill 보다 더 적극적으로 끌어올려 다크모드 가독성 확보.
    private var dozyTextColor: Color {
        (Color(hex: bar.colorHex) ?? .blue).eventTextColor(in: colorScheme)
    }
    private var isDozy: Bool { bar.source == .dozy }

    private var bgFill: Color { isDozy ? color.opacity(0.2) : color.opacity(0.75) }
    private var textColor: Color { isDozy ? dozyTextColor : .white }

    private var shape: UnevenRoundedRectangle {
        let leftRounded = bar.position == .single || bar.position == .start
        let rightRounded = bar.position == .single || bar.position == .end
        return UnevenRoundedRectangle(
            topLeadingRadius: leftRounded ? 4 : 0,
            bottomLeadingRadius: leftRounded ? 4 : 0,
            bottomTrailingRadius: rightRounded ? 4 : 0,
            topTrailingRadius: rightRounded ? 4 : 0
        )
    }

    var body: some View {
        shape
            .fill(bgFill)
            .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
            .overlay(alignment: .leading) {
                // 제목은 single / start 에만 표시. middle / end 는 색만 이어진다.
                if bar.position == .single || bar.position == .start {
                    HStack(spacing: 2) {
                        Text(bar.title)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                        if bar.isShared {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(textColor.opacity(0.85))
                        }
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 2)
                }
            }
            .clipped()
            // 단일 일정만 좌우 여유. 다일(start/middle/end) 는 컬럼 경계에서 끊김 없이 이어져야 해
            // 패딩을 주지 않는다.
            .padding(.horizontal, bar.position == .single ? 3 : 0)
    }
}
