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
                if viewModel.isSignedIn {
                    focusCard
                    Divider()
                    eventList
                } else {
                    signInPrompt
                }
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

    // MARK: - Sign-in Prompt

    private var signInPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("로그인 해서 일정을 확인하세요")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("앱을 열어 로그인하면 메뉴바에서도 오늘 일정을 볼 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                openMainWindow()
            } label: {
                Text("앱 열기")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Focus Card

    private var focusCard: some View {
        // 우선순위: 진행 중 시간 일정 → 다가오는 시간 일정 → 그 외 미완료 일정 (종일 / 이미 지난 것).
        // 마지막 fallback 까지 nil 이면 "오늘 일정 모두 완료" / "오늘 일정이 없습니다" 메시지.
        let display = viewModel.currentEvent
            ?? viewModel.upcomingEvent
            ?? viewModel.remainingEvents.first
        let isNow = viewModel.currentEvent != nil
        let isUpcoming = !isNow && viewModel.upcomingEvent != nil
        return Group {
            if let event = display {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: event.calendarColorHex) ?? .blue)
                        .frame(width: 3, height: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: focusIcon(isNow: isNow, isUpcoming: isUpcoming))
                                .font(.system(size: 9))
                                .foregroundStyle(isNow ? Color.green : Color.secondary)
                            Text(focusLabel(isNow: isNow, isUpcoming: isUpcoming))
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
                    Text(viewModel.todayEvents.isEmpty ? "오늘 일정이 없습니다" : "오늘 일정 모두 완료!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func focusIcon(isNow: Bool, isUpcoming: Bool) -> String {
        if isNow { return "circle.fill" }
        if isUpcoming { return "clock" }
        return "calendar"
    }

    private func focusLabel(isNow: Bool, isUpcoming: Bool) -> String {
        if isNow { return String(localized: "지금 일정") }
        if isUpcoming { return String(localized: "다음 일정") }
        return String(localized: "오늘 일정")
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
                let displayLimit = 5
                let displayed = Array(viewModel.sortedEventsForDisplay.prefix(displayLimit))
                let hidden = max(0, viewModel.todayEvents.count - displayLimit)

                VStack(spacing: 4) {
                    ForEach(displayed) { event in
                        eventRow(
                            event: event,
                            isCompleted: viewModel.completionsByID[event.id] == true
                        )
                    }
                    if hidden > 0 {
                        Button {
                            openMainWindow()
                        } label: {
                            HStack {
                                Text("+ \(hidden)개 더 보기")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func eventRow(event: CalendarEvent, isCompleted: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.calendarColorHex) ?? .blue)
                .frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    MacEventSourceIcon(source: event.source, size: 10)
                    Text(event.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .strikethrough(isCompleted, color: .secondary)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }
                Text(event.timeRangeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.toggleCompletion(for: event)
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isCompleted ? .green : .secondary.opacity(0.6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            openMainWindow()
        }
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
            // 로그인 안 한 상태에선 새 일정 만들기 비활성 — 데이터 저장 / 동기화 대상이 없음.
            .disabled(!viewModel.isSignedIn)

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
