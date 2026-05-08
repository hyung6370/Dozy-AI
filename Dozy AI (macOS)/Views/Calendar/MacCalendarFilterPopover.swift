//
//  MacCalendarFilterPopover.swift
//  Dozy AI (macOS)
//
//  캘린더 소스 / 공유 캘린더 가시성 필터 popover.
//  iOS 의 CalendarFilterSheet 와 동일한 토글 모델 — UserDefaults 영구 저장.
//

import SwiftUI
import AppKit

struct MacCalendarFilterPopover: View {

    @ObservedObject var filter: CalendarVisibilityFilter
    let sharedCalendars: [SharedCalendar]

    /// 토글로 노출할 소스 — naver 는 현재 미사용이라 제외.
    private let sources: [CalendarSource] = [.apple, .google, .dozy, .holiday]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("소스")
            VStack(spacing: 0) {
                ForEach(sources, id: \.self) { source in
                    sourceToggleRow(source)
                    if source != sources.last {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .padding(.vertical, 4)

            if !sharedCalendars.isEmpty {
                Divider().padding(.vertical, 4)
                sectionHeader("공유 캘린더")
                VStack(spacing: 0) {
                    ForEach(sharedCalendars) { cal in
                        sharedToggleRow(cal)
                        if cal.id != sharedCalendars.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if filter.isFilterActive {
                Divider().padding(.vertical, 4)
                Button {
                    filter.reset()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("모두 표시")
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 280)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    private func sourceToggleRow(_ source: CalendarSource) -> some View {
        Toggle(isOn: Binding(
            get: { filter.isVisible(source) },
            set: { filter.setVisible(source, $0) }
        )) {
            HStack(spacing: 10) {
                iconView(for: source)
                Text(source.displayName)
                    .font(.body)
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func sharedToggleRow(_ cal: SharedCalendar) -> some View {
        Toggle(isOn: Binding(
            get: { filter.isVisibleSharedCalendar(cal.id) },
            set: { filter.setVisibleSharedCalendar(cal.id, $0) }
        )) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                Text(cal.name)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// 소스별 커스텀 아이콘 — iOS 와 동일한 룩:
    /// - Apple: SF Symbol `apple.logo` 검정
    /// - Google: Assets 의 google 이미지셋
    /// - Dozy: 앱 번들의 AppIcon 런타임 로드
    /// - 그 외: 기존 SF Symbol
    @ViewBuilder
    private func iconView(for source: CalendarSource) -> some View {
        switch source {
        case .apple:
            Image(systemName: "apple.logo")
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
        case .google:
            Image("google")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        case .dozy:
            if let icon = Self.appIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: source.iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
        default:
            Image(systemName: source.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }

    /// macOS 는 NSApplication.shared.applicationIconImage 가 AppIcon.appiconset 의
    /// 현재 앱 아이콘을 직접 반환 — Bundle.main 경로 거칠 필요 없음.
    private static var appIconImage: NSImage? {
        NSApp.applicationIconImage
    }
}
