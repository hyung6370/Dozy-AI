//
//  CalendarFilterSheet.swift
//  Dozy AI
//
//  캘린더 소스 필터 시트 — 사용자가 Apple / Google / Dozy / 공휴일 등
//  보고 싶은 소스만 토글한다. 선택은 UserDefaults 에 영구 저장.
//

import SwiftUI
import UIKit

struct CalendarFilterSheet: View {

    @ObservedObject var filter: CalendarVisibilityFilter
    let sharedCalendars: [SharedCalendar]
    @Environment(\.dismiss) private var dismiss

    /// 토글로 노출할 소스 — naver 는 미사용, dozy 는 항상 표시(필터 대상에서 제외).
    private let sources: [CalendarSource] = [.apple, .google, .holiday]

    var body: some View {
        NavigationStack {
            List {
                Section("소스") {
                    ForEach(sources, id: \.self) { source in
                        Toggle(isOn: Binding(
                            get: { filter.isVisible(source) },
                            set: { filter.setVisible(source, $0) }
                        )) {
                            Label {
                                Text(source.displayName)
                            } icon: {
                                iconView(for: source)
                            }
                        }
                    }
                }

                if !sharedCalendars.isEmpty {
                    Section("공유 캘린더") {
                        ForEach(sharedCalendars) { cal in
                            Toggle(isOn: Binding(
                                get: { filter.isVisibleSharedCalendar(cal.id) },
                                set: { filter.setVisibleSharedCalendar(cal.id, $0) }
                            )) {
                                Label {
                                    Text(cal.name)
                                } icon: {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                    }
                }

                Section {
                    if filter.isFilterActive {
                        Button(role: .destructive) {
                            filter.reset()
                        } label: {
                            Label("모두 표시", systemImage: "arrow.counterclockwise")
                        }
                    }
                } footer: {
                    Text("끈 항목의 일정은 캘린더에 표시되지 않아요. 데이터는 그대로 유지됩니다.")
                }
            }
            .navigationTitle("캘린더 필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// 소스별 커스텀 아이콘 — 시스템 SF Symbol 대신 브랜드/에셋 노출:
    /// - Apple: SF Symbol `apple.logo` 검정으로
    /// - Google: Assets 의 "google" 이미지셋
    /// - Dozy: 앱 번들의 AppIcon 을 런타임에 로드 (AppIcon 변경 시 자동 반영)
    /// - 그 외: 기존 SF Symbol 유지
    @ViewBuilder
    private func iconView(for source: CalendarSource) -> some View {
        switch source {
        case .apple:
            Image(systemName: "apple.logo")
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
        case .google:
            Image("google")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        case .dozy:
            if let icon = Self.appIconImage {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: source.iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        default:
            Image(systemName: source.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
    }

    /// Bundle.main 의 CFBundleIcons 에서 AppIcon 의 마지막(가장 큰) 파일을 UIImage 로 로드.
    /// SwiftUI 의 Image("AppIcon") 은 .appiconset 에 직접 접근 불가라 이 경로를 거친다.
    private static var appIconImage: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let last = files.last
        else { return nil }
        return UIImage(named: last)
    }
}
