//
//  MacMonthPagingScrollView.swift
//  Dozy AI (macOS)
//
//  월간 캘린더의 가로 페이징을 SwiftUI ScrollView 의 .scrollTargetBehavior(.paging)
//  으로 처리. NSEvent 직접 monitor + liveOffset 수동 조작 방식 (60fps 마다
//  publish → 무거운 grid 의 .equatable() 가 매 프레임 검사) 의 stutter 제거.
//
//  - 트랙패드 / Magic Mouse 가로 스크롤이 OS 레벨에서 처리되어 손가락 follow
//    가 frame-perfect.
//  - LazyHStack ± windowRadius 개월 윈도우. 끝에 가까워지면 anchor 재조정.
//  - viewModel.currentMonth 와 양방향 동기화: 사용자가 스크롤로 페이지 바꾸면
//    VM 의 currentMonth 갱신, VM 이 외부 (Today / 메뉴 단축키) 로 currentMonth
//    바꾸면 그 페이지로 스크롤 이동.
//

import SwiftUI

struct MacMonthPagingScrollView<Page: View>: View {

    @ObservedObject var viewModel: MacCalendarViewModel
    let pageContent: (Date) -> Page

    /// 윈도우의 기준 월. 초기엔 viewModel.currentMonth, 끝에 가까워지면 재조정.
    @State private var anchorMonth: Date
    /// 현재 화면 가운데 페이지의 anchor 기준 offset (0 = anchor 자기 자신).
    @State private var scrolledOffset: Int? = 0
    /// 무한 루프 방지용 — 직전에 commit 한 offset. 양방향 binding 이 자기 변경을
    /// 다시 받아 또 변경하지 않게 가드.
    @State private var lastReportedOffset: Int = 0

    /// LazyHStack 에서 한 번에 hosting 할 페이지 수 = 2 * windowRadius + 1.
    /// 36 → 73 개월 (약 6 년). 이 범위를 넘기면 anchor 재조정으로 윈도우를 옮긴다.
    private static var windowRadius: Int { 36 }

    init(viewModel: MacCalendarViewModel, @ViewBuilder pageContent: @escaping (Date) -> Page) {
        self.viewModel = viewModel
        self.pageContent = pageContent
        self._anchorMonth = State(initialValue: viewModel.currentMonth)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(-Self.windowRadius...Self.windowRadius, id: \.self) { offset in
                    pageContent(month(for: offset))
                        .containerRelativeFrame(.horizontal)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledOffset, anchor: .center)
        .onChange(of: scrolledOffset) { _, newValue in
            guard let newValue, newValue != lastReportedOffset else { return }
            lastReportedOffset = newValue
            let newMonth = month(for: newValue)
            if !Calendar.current.isDate(viewModel.currentMonth,
                                        equalTo: newMonth,
                                        toGranularity: .month) {
                viewModel.currentMonth = newMonth
                viewModel.loadEventsForCurrentMonth()
            }
        }
        .onChange(of: viewModel.currentMonth) { _, newMonth in
            syncScrollPosition(to: newMonth)
        }
    }

    private func month(for offset: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: anchorMonth) ?? anchorMonth
    }

    /// 외부 (Today 버튼 / 메뉴 단축키 / chevron 버튼) 로 currentMonth 가 바뀌면
    /// 해당 offset 으로 ScrollView 를 이동. 윈도우 끝에 가까우면 anchor 재조정.
    private func syncScrollPosition(to target: Date) {
        let cal = Calendar.current
        let offset = cal.dateComponents([.month], from: anchorMonth, to: target).month ?? 0
        if abs(offset) > Self.windowRadius - 4 {
            // 윈도우 가장자리 근접 — anchor 를 target 으로 재조정해서 윈도우 한가운데로.
            anchorMonth = target
            lastReportedOffset = 0
            scrolledOffset = 0
            return
        }
        if offset != lastReportedOffset {
            lastReportedOffset = offset
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                scrolledOffset = offset
            }
        }
    }
}
