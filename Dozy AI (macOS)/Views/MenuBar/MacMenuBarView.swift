//
//  MacMenuBarView.swift
//  Dozy AI (macOS)
//
//  M4.10 — 메뉴바 팝오버 컨텐츠. 클릭 시 오늘 상태를 한눈에 보여주고
//  앱 열기 / 종료 액션 제공. .window 스타일 MenuBarExtra 에서 표시.
//

import SwiftUI
import AppKit

struct MacMenuBarView: View {
    let container: DependencyContainer
    @ObservedObject var viewModel: MacMenuBarViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showQuickAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showQuickAdd {
                MacMenuBarQuickAddView(
                    container: container,
                    onSaved: {
                        showQuickAdd = false
                        viewModel.loadTodayData()
                    },
                    onCancel: {
                        showQuickAdd = false
                    }
                )
            } else {
                header
                focusCard
                Divider()
                eventList
                Divider()
                actions
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear { viewModel.loadTodayData() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.todayDateString)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.greeting)
                .font(.headline)
        }
    }

    // MARK: - Focus Card

    private var focusCard: some View {
        let display = viewModel.currentEvent ?? viewModel.upcomingEvent
        let isNow = viewModel.currentEvent != nil
        return Group {
            if let event = display {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: event.calendarColorHex) ?? .blue)
                        .frame(width: 3, height: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: isNow ? "circle.fill" : "clock")
                                .font(.system(size: 9))
                                .foregroundStyle(isNow ? .green : .secondary)
                            Text(isNow ? "지금 일정" : "다음 일정")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(event.timeRangeString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(viewModel.todayEvents.isEmpty ? "오늘 일정이 없습니다" : "남은 일정이 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Event List

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("오늘 일정")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.remainingCount > 0 {
                    Text("\(viewModel.remainingCount)개 남음")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.todayEvents.isEmpty {
                Text("표시할 일정이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.todayEvents) { event in
                            eventRow(
                                event: event,
                                isCompleted: viewModel.completionsByID[event.id] == true
                            )
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func eventRow(event: CalendarEvent, isCompleted: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.calendarColorHex) ?? .blue)
                .frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                Text(event.timeRangeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                showQuickAdd = true
            } label: {
                Label("새 일정", systemImage: "plus.circle")
            }
            .keyboardShortcut("n")

            Button {
                openMainWindow()
            } label: {
                Label("앱 열기", systemImage: "macwindow")
            }

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("종료", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // WindowGroup 의 주 윈도우를 앞으로. 이미 있으면 포커스, 닫혀있으면 openWindow 로 재오픈
        if let main = NSApp.windows.first(where: { $0.isVisible && $0.contentViewController != nil }) {
            main.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
