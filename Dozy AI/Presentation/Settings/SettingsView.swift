//
//  SettingsView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/6/26.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSignOutAlert = false
    private let container: DependencyContainer
    
    init(container: DependencyContainer) {
        self.container = container
    }
    
    var body: some View {
        NavigationStack {
            List {
                accountSection
                calendarSection
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { authViewModel.restoreSession() }
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
                        Text("G")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
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
                Text("G")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
        case nil:
            Color.clear.frame(width: 34)
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
