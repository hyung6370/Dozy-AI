//
//  MacCalendarSettingsView.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 4/27/26.
//

import SwiftUI

struct MacCalendarSettingsView: View {
    @StateObject private var viewModel: MacCalendarSettingsViewModel
    
    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: MacCalendarSettingsViewModel(
            sourceManager: container.calendarSourceManager,
            appleCalendarService: container.appleCalendarServiceForSettings
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dozyRow
            appleRow
            // googleRow // macOS Google 연동 단계에서 활성화
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private var appleRow: some View {
        Toggle(isOn: $viewModel.isAppleEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Apple 캘린더", systemImage: "apple.logo")
                Text("macOS 기본 캘린더 일정을 Dozy 에서 함께 봅니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .disabled(viewModel.isRequestingAccess)
    }
    
    private var dozyRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label("Dozy 캘린더", systemImage: "checklist")
                Text("앱 내 직접 생성한 일정")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("항상 켜짐")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

