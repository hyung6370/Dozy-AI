//
//  MacCalendarWeekRow.swift
//  Dozy AI (macOS)
//
//  Phase 1 — 한 주(7일) 단위 렌더링:
//   1) 베이스: 7개 MacCalendarDayCell (날짜 숫자 + 오버플로우 배지)
//   2) 오버레이: 멀티데이 이벤트 바 (GeometryReader 로 정확한 col 기반 절대 위치)
//

import SwiftUI

struct MacCalendarWeekRow: View {
    let weekDates: [Date]              // 7일
    let currentMonth: Date             // 현재 보고 있는 월 (타월 dim 판정용)
    let selectedDate: Date
    let eventsByDate: [Date: [CalendarEvent]]
    let onSelectDate: (Date) -> Void
    let onSelectEvent: (CalendarEvent) -> Void
    let onCreateEvent: (Date) -> Void  // 더블 클릭 / 우클릭으로 새 이벤트
    let onGoToToday: () -> Void
    var onEditEvent: ((CalendarEvent) -> Void)? = nil
    var onDeleteEvent: ((CalendarEvent) -> Void)? = nil

    // 레이아웃 상수
    private let barHeight: CGFloat = 22
    private let barSpacing: CGFloat = 2
    private let barTopOffset: CGFloat = 42   // 날짜 숫자 영역 아래부터 바 시작
    private let barHorizontalInset: CGFloat = 3

    /// 첫 layout pass 가 끝났는지 추적. false 인 동안엔 이벤트 바의 hit-test 를 비활성화해
    /// 클릭이 아래 cell 로 통과하도록 한다 — 첫 렌더에서 cellWidth 가 일시적으로 부정확해도
    /// 셀(HStack 분배)은 정확하므로 항상 올바른 날짜가 선택됨. onAppear 직후 main.async 로
    /// true 로 토글 → 이후엔 정상적으로 바 hit-test 활성.
    @State private var layoutSettled = false

    var body: some View {
        return GeometryReader { geo in
            let cellWidth = geo.size.width / 7
            // 셀 높이에 들어가는 만큼 동적으로 결정 — 창 크기 변하면 자동 조정.
            // overflow 배지(+N) 영역 ~14px 도 함께 reserve. 0 (전부 오버플로우 배지) ~ 8 (상한) 범위.
            let availableForBars = geo.size.height - barTopOffset - 14
            let perBar = barHeight + barSpacing
            let dynamicMaxRows = max(0, min(8, Int((availableForBars + barSpacing) / perBar)))
            let layout = MacCalendarBarLayoutEngine.compute(
                weekDates: weekDates,
                eventsByDate: eventsByDate,
                maxVisibleRows: dynamicMaxRows
            )

            ZStack(alignment: .topLeading) {
                // 베이스 셀 — HStack 자동 분배에 맡김. .position() 으로 cellWidth 에 의존해
                // 명시 배치하면 첫 layout pass 의 부정확한 cellWidth 값으로 잠겨 정상화가 안 됨.
                // HStack 은 실제 layout pass 결과로 7개 셀을 균등 분배하므로 첫 렌더부터 정확.
                HStack(spacing: 0) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { col, date in
                        MacCalendarDayCell(
                            date: date,
                            isInCurrentMonth: isInMonth(date),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            isHoliday: hasHoliday(on: date),
                            overflowCount: layout.overflowByCol[col] ?? 0
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .trailing) {
                            if col < 6 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 1)
                                    .allowsHitTesting(false)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onCreateEvent(date) }
                        .simultaneousGesture(
                            TapGesture(count: 1)
                                .onEnded { onSelectDate(date) }
                        )
                        .contextMenu {
                            Button {
                                onCreateEvent(date)
                            } label: {
                                Label("새 일정", systemImage: "plus.circle")
                            }
                            if !Calendar.current.isDateInToday(date) {
                                Divider()
                                Button {
                                    onGoToToday()
                                } label: {
                                    Label("오늘로 이동", systemImage: "calendar.circle")
                                }
                            }
                        }
                    }
                }

                // 이벤트 바 오버레이
                ForEach(layout.bars) { bar in
                    eventBar(bar: bar, cellWidth: cellWidth)
                }
            }
            // SpatialTapGesture 가 weekRow 좌표계에서 위치를 받도록 명시. 이벤트 바의 col 계산에 사용.
            .coordinateSpace(.named("weekRow"))
            // 셀 높이를 넘는 바가 옆 행으로 leak 되지 않도록 강제 클리핑.
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                // 첫 layout pass 후 한 번 settled 토글 → 이벤트 바의 hit-test 활성화.
                DispatchQueue.main.async {
                    layoutSettled = true
                }
            }
        }
    }

    private func eventBar(bar: MacCalendarEventBar, cellWidth: CGFloat) -> some View {
        let span = CGFloat(bar.endCol - bar.startCol + 1)
        let width = cellWidth * span - barHorizontalInset * 2
        let xCenter = cellWidth * CGFloat(bar.startCol) + cellWidth * span / 2
        let y = barTopOffset + CGFloat(bar.stackRow) * (barHeight + barSpacing) + barHeight / 2

        // 바가 걸친 컬럼 중 하나라도 현재 월에 속하면 풀 opacity, 아니면 dim.
        let touchesCurrentMonth = (bar.startCol...bar.endCol).contains { col in
            guard col < weekDates.count else { return false }
            return isInMonth(weekDates[col])
        }

        return EventBarView(event: bar.event)
            .frame(width: max(0, width), height: barHeight)
            .opacity(touchesCurrentMonth ? 1.0 : 0.4)
            .position(x: xCenter, y: y)
            // (1) 공휴일 등 read-only 이벤트 바, (2) layout 이 아직 settled 안 된 첫 렌더 윈도우
            //  → hit testing 비활성화 → 클릭이 아래 cell 로 통과해 정확한 날짜 선택 보장.
            .allowsHitTesting(layoutSettled && !bar.event.isReadOnly)
            // 일반 바는 클릭 위치(x)로부터 어느 col 위에 있었는지 계산해 date 선택과 이벤트 상세 둘 다 트리거.
            // .named("weekRow") 좌표계 사용 → value.location.x 가 weekRow 절대 좌표라 바로 col 계산 가능.
            .gesture(
                SpatialTapGesture(count: 1, coordinateSpace: .named("weekRow"))
                    .onEnded { value in
                        let col = max(0, min(6, Int(value.location.x / cellWidth)))
                        if col < weekDates.count {
                            onSelectDate(weekDates[col])
                        }
                        onSelectEvent(bar.event)
                    }
            )
            .contextMenu {
                if !bar.event.isReadOnly {
                    Button {
                        onEditEvent?(bar.event)
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDeleteEvent?(bar.event)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
    }

    private func isInMonth(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: currentMonth)
            && cal.component(.year, from: date) == cal.component(.year, from: currentMonth)
    }

    /// 해당 날짜에 공휴일 source 의 이벤트가 있는지.
    private func hasHoliday(on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return (eventsByDate[day] ?? []).contains { $0.source == .holiday }
    }
}

// 클로저 프로퍼티 때문에 자동 derive 가 안 되어 데이터 필드만 비교한다.
// eventsByDate 전체(42칸) 를 비교하면 비싸서, 이 row 가 보는 7일치만 슬라이스해서 비교 →
// 캘린더 페이징 시 변하지 않은 row 는 SwiftUI 가 .equatable() 로 body 호출 자체를 skip.
extension MacCalendarWeekRow: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.weekDates == rhs.weekDates,
              lhs.currentMonth == rhs.currentMonth,
              Calendar.current.isDate(lhs.selectedDate, inSameDayAs: rhs.selectedDate)
        else { return false }
        for date in lhs.weekDates {
            if (lhs.eventsByDate[date] ?? []) != (rhs.eventsByDate[date] ?? []) {
                return false
            }
        }
        return true
    }
}

// MARK: - EventBarView

private struct EventBarView: View {
    let event: CalendarEvent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = Color(hex: event.calendarColorHex) ?? .blue
        // 다크 모드에선 가독성을 위해 텍스트·아이콘을 흰색으로 통일. 단, 공휴일은
        // 빨강이 의미를 갖는 시그널이라 다크모드에서도 원색 유지.
        // 다크 모드: 일반 일정은 흰색, 공휴일은 원래 빨강 그대로 (어둡게 처리하면 안 보임).
        // 라이트 모드: 카테고리 색을 35% 어둡게 — material 위에서 또렷이 읽히도록.
        let foreground: Color = colorScheme == .dark
            ? (event.source == .holiday ? color : .white)
            : color.adjustingBrightness(0.65)
        HStack(spacing: 3) {
            Rectangle().fill(color).frame(width: 3)
            if event.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(foreground)
                    .padding(.leading, 3)
            }
            MacEventSourceIcon(source: event.source, size: 10, tint: foreground)
                .padding(.leading, event.isPinned ? 0 : 4)
            Text(event.title)
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, (event.isPinned || event.source == .apple || event.source == .google) ? 0 : 5)
                .padding(.trailing, 5)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .themedEventChipBackground(color: color, cornerRadius: 7)
        .contentShape(Rectangle())
    }
}
