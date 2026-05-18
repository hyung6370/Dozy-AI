//
//  MacSettingsView.swift
//  Dozy AI (macOS)
//
//  M4.8 — 설정 섹션의 실제 뷰. 계정 / 카테고리 관리 / 앱 정보 / 탈퇴.
//  공유 캘린더 관리는 M4.8b 에서 추가 예정.
//

import SwiftUI
import SwiftData

struct MacSettingsView: View {
    @EnvironmentObject private var authViewModel: MacAuthViewModel

    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showCategoryManagement = false
    @State private var showSharedCalendarManagement = false
    @State private var showShortcutsHelp = false
    @State private var showPasswordChange = false
    @AppStorage("menuBarShowBadge") private var menuBarShowBadge: Bool = true
    @AppStorage("macBackgroundTheme")
    private var backgroundThemeRaw: String = MacBackgroundTheme.defaultTheme.rawValue

    private var backgroundTheme: MacBackgroundTheme {
        MacBackgroundTheme(rawValue: backgroundThemeRaw) ?? .defaultTheme
    }

    /// iOS 와 공유하는 Setting/* 에셋 이름. light/dark 자동 분기.
    private func settingsAsset(_ stem: String) -> String {
        "\(colorScheme == .dark ? "Dark" : "Light")-\(stem)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                accountSection
                categorySection
                appearanceSection
                menuBarSection
                calendarIntegrationSection
                sharedCalendarSection
                helpSection
                appInfoSection
                if authViewModel.currentUser?.provider == .email {
                    passwordChangeSection
                }
                dangerZoneSection
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 720, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("설정")
        .alert("로그아웃", isPresented: $showSignOutAlert) {
            Button("로그아웃", role: .destructive) { authViewModel.signOut() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("정말로 로그아웃 하시겠습니까?")
        }
        .alert("계정을 탈퇴하시겠습니까?", isPresented: $showDeleteAccountAlert) {
            Button("탈퇴", role: .destructive) { authViewModel.deleteAccount() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("모든 일정, 기록, 카테고리가 영구적으로 삭제됩니다.")
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { authViewModel.errorMessage != nil },
                set: { if !$0 { authViewModel.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) { authViewModel.errorMessage = nil }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showCategoryManagement) {
            MacCategoryManagementView()
        }
        .sheet(isPresented: $showSharedCalendarManagement) {
            MacSharedCalendarListView(container: container)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showShortcutsHelp) {
            MacShortcutsHelpSheet()
        }
        .sheet(isPresented: $showPasswordChange) {
            MacPasswordChangeSheet()
                .environmentObject(authViewModel)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("계정")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                providerIcon(for: authViewModel.currentUser?.provider)
                VStack(alignment: .leading, spacing: 4) {
                    Text(authViewModel.currentUser?.email ?? String(localized: "사용자"))
                        .font(.body)
                        .fontWeight(.semibold)
                    Text(providerLabel(for: authViewModel.currentUser?.provider))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("로그아웃") {
                    showSignOutAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.08), Color.accentColor.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func providerIcon(for provider: AuthProvider?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            switch provider {
            case .apple:
                Image(systemName: "apple.logo").font(.title2)
            case .google:
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            case .email:
                Image(systemName: "envelope.fill").font(.title3)
            case nil:
                Image(systemName: "person.fill").font(.title3).foregroundStyle(.secondary)
            }
        }
    }

    private func providerLabel(for provider: AuthProvider?) -> String {
        switch provider {
        case .apple:  return String(localized: "Apple 로그인")
        case .google: return String(localized: "Google 로그인")
        case .email:  return String(localized: "이메일 로그인")
        case nil:     return String(localized: "로그인 필요")
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        SettingsSection(title: "카테고리") {
            Button {
                showCategoryManagement = true
            } label: {
                settingsRow(
                    asset: settingsAsset("Management-Category"),
                    title: "카테고리 관리"
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SettingsSection(title: "테마") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("배경", selection: $backgroundThemeRaw) {
                    ForEach(MacBackgroundTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(backgroundTheme.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Menu Bar

    private var menuBarSection: some View {
        SettingsSection(title: "메뉴바") {
            Toggle(isOn: $menuBarShowBadge) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("남은 일정 개수 배지", systemImage: "app.badge")
                    Text("메뉴바 아이콘 옆에 오늘 남은 일정 수를 표시합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }
    
    // MARK: - Calendar Integration
    
    private var calendarIntegrationSection: some View {
        SettingsSection(title: "캘린더 연동") {
            MacCalendarSettingsView(container: container)
        }
    }

    // MARK: - Shared Calendar

    private var sharedCalendarSection: some View {
        SettingsSection(title: "공유 캘린더") {
            Button {
                showSharedCalendarManagement = true
            } label: {
                settingsRow(
                    asset: settingsAsset("Share-Calendar"),
                    title: "파트너와 공유"
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Help

    private var helpSection: some View {
        SettingsSection(title: "도움말") {
            Button {
                showShortcutsHelp = true
            } label: {
                settingsRow(
                    asset: settingsAsset("Version"),
                    title: "단축키 · 사용 팁"
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    // MARK: - App Info

    private var privacyPolicyURL: URL? {
        guard
            let str = Bundle.main.infoDictionary?["PRIVACY_POLICY_URL"] as? String,
            let url = URL(string: str)
        else { return nil }
        return url
    }

    private var appInfoSection: some View {
        SettingsSection(title: "앱 정보") {
            Button {
                if let url = privacyPolicyURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                settingsRow(asset: settingsAsset("Privacy"), title: "개인정보 처리방침")
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(privacyPolicyURL == nil)

            HStack(spacing: 10) {
                Image(settingsAsset("Version"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text("버전")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Password Change (이메일 로그인 사용자 한정)

    private var passwordChangeSection: some View {
        SettingsSection(title: "비밀번호 변경") {
            Button {
                showPasswordChange = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                    Text("비밀번호 변경")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        SettingsSection(title: "계정 탈퇴") {
            Button {
                showDeleteAccountAlert = true
            } label: {
                HStack(spacing: 10) {
                    Image(settingsAsset("Delete-Account"))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("계정 탈퇴")
                        .foregroundStyle(.red)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// 공통 설정 행 — 좌측 커스텀 에셋 아이콘 + 제목 + 우측 chevron.
    /// frame + contentShape 로 행 전체(여백·chevron 포함)가 클릭 가능하도록.
    private func settingsRow(asset: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Shortcuts Help Sheet

private struct MacShortcutsHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HelpGroup(title: "섹션 이동") {
                        ShortcutRow(keys: ["⌘", "1"], label: "오늘")
                        ShortcutRow(keys: ["⌘", "2"], label: "캘린더")
                        ShortcutRow(keys: ["⌘", "3"], label: "인사이트")
                        ShortcutRow(keys: ["⌘", "4"], label: "설정")
                    }

                    HelpGroup(title: "캘린더 탐색") {
                        ShortcutRow(keys: ["⌘", "T"], label: "오늘로 이동")
                        ShortcutRow(keys: ["⌘", "["], label: "이전 기간 (월·주·일)")
                        ShortcutRow(keys: ["⌘", "]"], label: "다음 기간")
                    }

                    HelpGroup(title: "일정 · 새로고침") {
                        ShortcutRow(keys: ["⌘", "N"], label: "새 일정")
                        ShortcutRow(keys: ["⌘", "R"], label: "데이터 새로고침")
                    }

                    HelpGroup(title: "도구 · 윈도우") {
                        ShortcutRow(keys: ["⌘", "⇧", "A"], label: "AI 요약 생성")
                        ShortcutRow(keys: ["⌘", "⇧", "C"], label: "캘린더 단독 창 열기")
                    }

                    HelpGroup(title: "사용 팁") {
                        TipRow(
                            icon: "hand.tap",
                            title: "캘린더 셀 더블클릭",
                            detail: "그 날짜에 새 일정을 바로 만들 수 있어요."
                        )
                        TipRow(
                            icon: "cursorarrow.click.2",
                            title: "셀 우클릭",
                            detail: "새 일정 / 오늘로 이동 등 컨텍스트 메뉴가 열려요."
                        )
                        TipRow(
                            icon: "clock",
                            title: "일 뷰 시간 슬롯 더블클릭",
                            detail: "선택한 시각에 새 일정을 만들 수 있어요."
                        )
                        TipRow(
                            icon: "menubar.rectangle",
                            title: "메뉴바 팝오버",
                            detail: "일정 행을 누르면 메인 윈도우로 점프하고, 체크 박스로 완료 상태를 토글합니다."
                        )
                        TipRow(
                            icon: "person.2",
                            title: "공유 캘린더",
                            detail: "설정 → 파트너와 공유에서 초대 코드를 발급해 일정을 함께 볼 수 있어요."
                        )
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("단축키 · 사용 팁")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .frame(width: 520, height: 620)
    }
}

private struct HelpGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCardSurface(cornerRadius: 12)
        }
    }
}

private struct ShortcutRow: View {
    let keys: [String]
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.body)
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 6)
                        .background(Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                }
            }
        }
    }
}

private struct TipRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - SettingsSection

private struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCardSurface(cornerRadius: 14)
        }
    }
}
