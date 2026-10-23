//
//  VoiceInputView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import SwiftUI

/// 음성 시트의 용도별 문구. 녹음, 권한, 상태 머신은 공유하고 제목/저장 버튼/안내문만 다르다.
struct VoiceInputStyle {
    let title: LocalizedStringKey
    let saveLabel: LocalizedStringKey
    let placeholder: String
    let idleHint: LocalizedStringKey
    
    /// 홈 메모 (기본값)
    static let memo = VoiceInputStyle(
        title: "음성 메모",
        saveLabel: "메모로 저장",
        placeholder: String(localized: "말씀해 보세요..."),
        idleHint: "저장하거나 다시 녹음할 수 있어요"
    )
    
    /// 새 일정 빠른 입력 - 받아쓴 문장을 일정 폼에 채운다
    static let event = VoiceInputStyle(
        title: "음성으로 일정 입력",
        saveLabel: "일정으로 채우기",
        placeholder: String(localized: "예: 내일 오후 3시 치과 30분"),
        idleHint: "채우거나 다시 녹음할 수 있어요"
    )
}

struct VoiceInputView: View {
    
    @StateObject private var viewModel: VoiceInputViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    private let style: VoiceInputStyle
    private let onSave: (String) -> Void
    
    init(speechService: SpeechServiceProtocol, style: VoiceInputStyle = .memo, onSave: @escaping (String) -> Void) {
        _viewModel = StateObject(wrappedValue: VoiceInputViewModel(speechService: speechService))
        self.style = style
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                transcriptArea
                Spacer(minLength: 0)
                statusLabel
                micButton
                actionButtons
            }
            .padding(20)
            .navigationTitle(style.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { viewModel.start() }       // 시트가 뜨자마자 듣기 시작
        .onDisappear { viewModel.cancel() }   // 어떤 경로로 닫혀도 마이크 해제
    }
    
    // MARK: - Subviews
    
    private var transcriptArea: some View {
        ScrollView {
            Text(viewModel.transcript.isEmpty ? style.placeholder : viewModel.transcript)
                .font(.title3)
                .foregroundStyle(viewModel.transcript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .frame(minHeight: 140)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }
    
    private var statusLabel: some View {
        Group {
            switch viewModel.phase {
            case .idle:
                Text(viewModel.transcript.isEmpty ? "마이크를 눌러 시작" : style.idleHint)
            case .requestingPermission:
                Text("권한 확인 중…")
            case .listening:
                Text("듣는 중… 끝나면 마이크를 다시 누르세요")
            case .finishing:
                Text("정리 중…")
            case .denied:
                VStack(spacing: 8) {
                    Text("음성 인식 또는 마이크 권한이 꺼져 있어요")
                    Button("설정에서 허용") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    
    private var micButton: some View {
        Button { viewModel.toggleListening() } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isListening ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 96, height: 96)
                    .scaleEffect(viewModel.isListening ? 1.15 : 1.0)
                    .animation(
                        viewModel.isListening
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                        value: viewModel.isListening
                    )
                Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(viewModel.isListening ? .red : .blue)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.phase == .requestingPermission || viewModel.phase == .finishing)
        .accessibilityLabel(viewModel.isListening ? "녹음 중지" : "녹음 시작")
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.start()
            } label: {
                Label("다시 녹음", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isListening || viewModel.transcript.isEmpty)
            
            Button {
                onSave(viewModel.trimmedTranscript)
                dismiss()
            } label: {
                Label(style.saveLabel, systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave)
        }
    }
}
