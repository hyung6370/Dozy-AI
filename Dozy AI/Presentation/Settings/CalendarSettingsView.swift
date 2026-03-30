//
//  CalendarSettingsView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import SwiftUI

struct CalendarSettingsView: View {
    
    @StateObject private var viewModel: CalendarSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(sourceManager: CalendarSourceManager, signInService: GoogleSignInService) {
        _viewModel = StateObject(wrappedValue: CalendarSettingsViewModel(
            sourceManager: sourceManager,
            signInService: signInService
        ))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    dozyRow
                    appleRow
                    googleRow
                } header: {
                    Text("연결된 캘린더")
                } footer: {
                    Text("활성화된 캘린더의 일정이 Dozy AI 분석에 포함됩니다.")
                }
            }
            .navigationTitle("캘린더 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Google 로그인 실패", isPresented: Binding(
                get: { viewModel.googleSignInError != nil },
                set: { if !$0 { viewModel.googleSignInError = nil } }
            )) {
                Button("확인", role: .cancel) { viewModel.googleSignInError = nil }
            } message: {
                Text(viewModel.googleSignInError ?? "")
            }
        }
    }
    
    // MARK: - Apple Row
    private var appleRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "apple.logo")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 34)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple 캘린더")
                    .font(.subheadline).fontWeight(.medium)
                Text("iPhone 기본 캘린더")
                    .font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { viewModel.sourceManager.isEnabled(.apple) },
                set: { _ in viewModel.toggleApple() }
            )).labelsHidden()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Google Row
    private var googleRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)
                Text("G")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Google 캘린더")
                    .font(.subheadline).fontWeight(.medium)
                Text(viewModel.googleUserEmail ?? "연결되지 않음")
                    .font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if viewModel.isGoogleSignedIn {
                VStack(spacing: 6) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.sourceManager.isEnabled(.google) },
                        set: { _ in viewModel.sourceManager.toggle(.google) }
                    ))
                    .labelsHidden()
                    
                    Button("연결 해제") { viewModel.disconnectGoogle() }
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                }
            } else {
                Button("연결") { viewModel.connectGoogle() }
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Dozy Row
    private var dozyRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "d.circle.fill")
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 34)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Dozy 캘린더")
                    .font(.subheadline).fontWeight(.medium)
                Text("앱 내 직접 생성한 일정")
                    .font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("항상 켜짐")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
