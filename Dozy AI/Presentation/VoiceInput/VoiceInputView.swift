//
//  VoiceInputView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import SwiftUI

struct VoiceInputView: View {
    
    @StateObject private var viewModel: VoiceInputViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    private let onSave: (String) -> Void
    
    init(speechService: SpeechServiceProtocol, onSave: @escaping (String) -> Void) {
        _viewModel = StateObject(wrappedValue: VoiceInputViewModel(speechService: speechService))
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
            .navigationTitle("음성 메모")
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
            Text(viewModel.transcript.isEmpty ? String(localized: "말씀해 보세요...") : viewModel.transcript)
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
                Text(viewModel.transcript.isEmpty ? "마이크를 눌러 시작" : "저장하거나 다시 녹음할 수 있어요")
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
                Label("메모로 저장", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave)
        }
    }
}
