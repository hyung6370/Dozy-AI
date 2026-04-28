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
    @AppStorage("menuBarShowBadge") private var menuBarShowBadge: Bool = true

    /// iOS 와 공유하는 Setting/* 에셋 이름. light/dark 자동 분기.
    private func settingsAsset(_ stem: String) -> String {
        "\(colorScheme == .dark ? "Dark" : "Light")-\(stem)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                accountSection
                categorySection
                menuBarSection
                calendarIntegrationSection
                sharedCalendarSection
                appInfoSection
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
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("계정")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                providerIcon(for: authViewModel.currentUser?.provider)
                VStack(alignment: .leading, spacing: 4) {
                    Text(authViewModel.currentUser?.email ?? "사용자")
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
        case .apple:  return "Apple 로그인"
        case .google: return "Google 로그인"
        case .email:  return "이메일 로그인"
        case nil:     return "로그인 필요"
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

    // MARK: - Menu Bar

    private var menuBarSection: some View {
        SettingsSection(title: "메뉴바") {
            Toggle(isOn: $menuBarShowBadge) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("남은 일정 개수 배지", systemImage: "circle.badge")
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

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        SettingsSection(title: "위험 구역") {
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
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    /// 공통 설정 행 — 좌측 커스텀 에셋 아이콘 + 제목 + 우측 chevron.
    private func settingsRow(asset: String, title: String) -> some View {
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
    }
}

// MARK: - SettingsSection

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }
}
