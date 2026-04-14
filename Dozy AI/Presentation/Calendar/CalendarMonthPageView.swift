//
//  CalendarMonthPageView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/10/26.
//

import SwiftUI

// MARK: - MonthPageViewController

/// UIPageViewController 기반 월 달력 페이저.
/// 팬 제스처를 UIKit 레벨에서 처리하므로 SwiftUI 렌더링 오버헤드가 없다.
struct MonthPageViewController: UIViewControllerRepresentable {

    let currentMonth: Date
    let weekLayouts: [Date: [CalendarEventLayout]]
    let selectedDate: Date
    let isToday: (Date) -> Bool
    let isSelected: (Date) -> Bool
    let onSelect: (Date) -> Void
    let onLongPress: (Date) -> Void
    let onTapEvent: (String, Date) -> Void
    let onOverflowTap: (Date) -> Void
    let onMonthChanged: (Date) -> Void
    let onWillChangeMonth: (Date) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let vc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        vc.view.backgroundColor = .clear
        vc.dataSource = context.coordinator
        vc.delegate = context.coordinator
        context.coordinator.pageVC = vc

        let initial = context.coordinator.makeCell(for: currentMonth)
        vc.setViewControllers([initial], direction: .forward, animated: false)
        return vc
    }

    func updateUIViewController(_ vc: UIPageViewController, context: Context) {
        let coord = context.coordinator
        coord.parent = self

        // 현재 페이지의 이벤트 레이아웃·선택 날짜 갱신
        vc.viewControllers?.compactMap { $0 as? MonthPageCell }.forEach {
            $0.update(weekLayouts: weekLayouts, selectedDate: selectedDate)
        }

        // 외부 네비게이션 (chevron / 날짜 picker) 처리
        guard
            let current = vc.viewControllers?.first as? MonthPageCell,
            current.month != currentMonth,
            !coord.isNavigating
        else { return }

        coord.isNavigating = true
        let direction: UIPageViewController.NavigationDirection =
            currentMonth > current.month ? .forward : .reverse
        let newVC = coord.makeCell(for: currentMonth)
        vc.setViewControllers([newVC], direction: direction, animated: true) { _ in
            coord.isNavigating = false
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: MonthPageViewController
        weak var pageVC: UIPageViewController?
        var isNavigating = false

        init(_ parent: MonthPageViewController) { self.parent = parent }

        func makeCell(for month: Date) -> MonthPageCell {
            MonthPageCell(
                month: month,
                weekLayouts: parent.weekLayouts,
                selectedDate: parent.selectedDate,
                isToday: parent.isToday,
                isSelected: parent.isSelected,
                onSelect: parent.onSelect,
                onLongPress: parent.onLongPress,
                onTapEvent: parent.onTapEvent,
                onOverflowTap: parent.onOverflowTap
            )
        }

        // MARK: UIPageViewControllerDataSource

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let cell = vc as? MonthPageCell else { return nil }
            let prev = Calendar.current.date(byAdding: .month, value: -1, to: cell.month)!
            return makeCell(for: prev)
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let cell = vc as? MonthPageCell else { return nil }
            let next = Calendar.current.date(byAdding: .month, value: 1, to: cell.month)!
            return makeCell(for: next)
        }

        // MARK: UIPageViewControllerDelegate

        func pageViewController(_ pvc: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            guard !isNavigating,
                  let cell = pendingViewControllers.first as? MonthPageCell
            else { return }
            parent.onWillChangeMonth(cell.month)
        }

        func pageViewController(_ pvc: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard let cell = pvc.viewControllers?.first as? MonthPageCell else { return }
            if !completed {
                // 스와이프 취소 → 높이를 바꾼 적 없으므로 복원 불필요
                return
            }
            guard !isNavigating else { return }
            parent.onMonthChanged(cell.month)
        }
    }
}

// MARK: - MonthPageCell

final class MonthPageCell: UIHostingController<MonthGridContent> {

    let month: Date

    init(month: Date,
         weekLayouts: [Date: [CalendarEventLayout]],
         selectedDate: Date,
         isToday: @escaping (Date) -> Bool,
         isSelected: @escaping (Date) -> Bool,
         onSelect: @escaping (Date) -> Void,
         onLongPress: @escaping (Date) -> Void,
         onTapEvent: @escaping (String, Date) -> Void,
         onOverflowTap: @escaping (Date) -> Void) {
        self.month = month
        super.init(rootView: MonthGridContent(
            month: month,
            weekLayouts: weekLayouts,
            selectedDate: selectedDate,
            isToday: isToday,
            isSelected: isSelected,
            onSelect: onSelect,
            onLongPress: onLongPress,
            onTapEvent: onTapEvent,
            onOverflowTap: onOverflowTap
        ))
        view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder: NSCoder) { fatalError() }

    func update(weekLayouts: [Date: [CalendarEventLayout]], selectedDate: Date) {
        rootView = MonthGridContent(
            month: month,
            weekLayouts: weekLayouts,
            selectedDate: selectedDate,
            isToday: rootView.isToday,
            isSelected: rootView.isSelected,
            onSelect: rootView.onSelect,
            onLongPress: rootView.onLongPress,
            onTapEvent: rootView.onTapEvent,
            onOverflowTap: rootView.onOverflowTap
        )
    }
}

// MARK: - MonthGridContent

struct MonthGridContent: View {

    let month: Date
    let weekLayouts: [Date: [CalendarEventLayout]]
    let selectedDate: Date
    let isToday: (Date) -> Bool
    let isSelected: (Date) -> Bool
    let onSelect: (Date) -> Void
    let onLongPress: (Date) -> Void
    let onTapEvent: (String, Date) -> Void
    let onOverflowTap: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                MonthWeekRowView(
                    weekDates: week,
                    layouts: weekLayouts[
                        Calendar.current.startOfDay(for: weekStart(weekIndex: weekIndex))
                    ] ?? [],
                    selectedDate: selectedDate,
                    isToday: isToday,
                    isSelected: isSelected,
                    isInMonth: isInCurrentMonth,
                    onSelect: onSelect,
                    onLongPress: onLongPress,
                    onTapEvent: onTapEvent,
                    onOverflowTap: onOverflowTap
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var weeks: [[Date]] {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let weekday = cal.component(.weekday, from: first) - 1
        let range = cal.range(of: .day, in: .month, for: month)!
        var days: [Date] = []
        for i in 0..<weekday {
            days.append(cal.date(byAdding: .day, value: i - weekday, to: first)!)
        }
        for day in range {
            var comps = cal.dateComponents([.year, .month], from: month)
            comps.day = day
            days.append(cal.date(from: comps)!)
        }
        var extra = 1
        while days.count % 7 != 0 {
            days.append(cal.date(byAdding: .day, value: range.count - 1 + extra, to: first)!)
            extra += 1
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0+7]) }
    }

    private func isInCurrentMonth(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: month)
            && cal.component(.year, from: date) == cal.component(.year, from: month)
    }

    private func weekStart(weekIndex: Int) -> Date {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let weekday = cal.component(.weekday, from: first) - 1
        let start = cal.date(byAdding: .day, value: -weekday, to: first)!
        return cal.date(byAdding: .day, value: weekIndex * 7, to: start)!
    }
}
