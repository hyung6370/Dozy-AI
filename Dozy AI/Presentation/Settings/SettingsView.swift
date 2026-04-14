//
//  SettingsView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/6/26.
//

import SwiftUI
import Lottie
import SafariServices

struct SettingsView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    private let container: DependencyContainer

    private var privacyPolicyURL: URL? {
        guard
            let str = Bundle.main.infoDictionary?["PRIVACY_POLICY_URL"] as? String,
            let url = URL(string: str)
        else { return nil }
        return url
    }
    
    init(container: DependencyContainer) {
        self.container = container
    }
    
    var body: some View {
        NavigationStack {
            List {
                accountSection
                calendarSection
                categorySection
                infoSection
                dangerZoneSection
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if authViewModel.showCongratulationAnimation {
                    LottieView(name: "congratulation", loopMode: .playOnce) {
                        authViewModel.showCongratulationAnimation = false
                    }
                    .scaleEffect(0.3)
                    .allowsHitTesting(false)
                }
            }
            .alert("로그아웃", isPresented: $showSignOutAlert) {
                Button("로그아웃", role: .destructive) { authViewModel.signOut() }
                Button("취소", role: .cancel) { }
            } message: {
                Text("정말로 로그아웃 하시겠습니까?")
            }
            .alert("오류", isPresented: Binding(
                get: { authViewModel.errorMessage != nil },
                set: { if !$0 { authViewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { authViewModel.errorMessage = nil }
            } message: {
                Text(authViewModel.errorMessage ?? "")
            }
            .alert("계정을 탈퇴하시겠습니까?", isPresented: $showDeleteAccountAlert) {
                Button("탈퇴", role: .destructive) {
                    authViewModel.deleteAccount()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("모든 일정, 기록, 카테고리가 영구적으로 삭제됩니다.")
            }
        }
    }
    
    // MARK: - 계정 섹션
    
    private var accountSection: some View {
        Section {
            if authViewModel.isLoggedIn {
                loggedInRow
            } else {
                loggedOutRow
            }
        } header: {
            Text("계정")
        } footer: {
            Text(authViewModel.isLoggedIn
                 ? "로그인 상태에서는 데이터가 서버에 백업됩니다."
                 : "로그인하면 기기를 바꿔도 데이터를 유지할 수 있어요.")
        }
    }
    
    private var loggedInRow: some View {
        HStack(spacing: 14) {
            providerIcon(for: authViewModel.currentUser?.provider)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(authViewModel.currentUser?.displayName ?? "사용자")
                    .font(.subheadline).fontWeight(.medium)
                Text(authViewModel.currentUser?.email ?? "")
                    .font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("로그아웃") { showSignOutAlert = true }
                .font(.subheadline)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private var loggedOutRow: some View {
        VStack(spacing: 12) {
            if authViewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                // Apple 로그인
                Button { authViewModel.signInWithApple() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .medium))
                        Text("Apple로 로그인")
                            .font(.subheadline).fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                }
                .buttonStyle(.plain)
                
                // Google 로그인
                Button { authViewModel.signInWithGoogle() } label: {
                    HStack(spacing: 10) {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("Google로 로그인")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func providerIcon(for provider: AuthProvider?) -> some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 34)
        case .google:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
        case nil:
            Color.clear.frame(width: 34)
        }
    }
    
    // MARK: - 카테고리 섹션

    private var categorySection: some View {
        Section {
            NavigationLink {
                CategoryManagementView()
            } label: {
                Label("카테고리 관리", systemImage: "tag")
            }
        } header: {
            Text("카테고리")
        }
    }

    // MARK: - 앱 정보 섹션

    private var infoSection: some View {
        Section {
            Button {
                guard let url = privacyPolicyURL,
                      let topVC = UIApplication.shared.topViewController else { return }
                let safari = SFSafariViewController(url: url)
                topVC.present(safari, animated: true)
            } label: {
                Label("개인정보 처리방침", systemImage: "hand.raised")
            }
            .foregroundStyle(.primary)
            .disabled(privacyPolicyURL == nil)

            HStack {
                Label("버전", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("앱 정보")
        }
    }

    // MARK: - 계정 탈퇴 섹션

    @ViewBuilder
    private var dangerZoneSection: some View {
        if authViewModel.isLoggedIn {
            Section {
                Button(role: .destructive) {
                    showDeleteAccountAlert = true
                } label: {
                    Label("계정 탈퇴", systemImage: "person.crop.circle.badge.minus")
                }
            } footer: {
                Text("탈퇴 시 모든 데이터가 영구 삭제되며 복구할 수 없습니다.")
            }
        }
    }

    // MARK: - 캘린더 섹션

    private var calendarSection: some View {
        Section {
            NavigationLink {
                CalendarSettingsView(
                    sourceManager: container.calendarSourceManager,
                    googleSignInService: container.googleSignInService,
                    naverSignInService: container.naverSignInService
                )
            } label: {
                Label("캘린더 연동", systemImage: "calendar.badge.plus")
            }
        } header: {
            Text("캘린더")
        }
    }
}
