//
//  VoiceInputViewModel.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

/**
 [MVVM] 음성 메모 시트의 상태 머신
   idle → requestingPermission → listening → finishing → idle(결과 보유)
                               ↘ denied / failed
   SpeechServiceProtocol만 알고 Speech 프레임워크는 모른다
 */

import Foundation
import Combine

@MainActor
final class VoiceInputViewModel: ObservableObject {
    
    enum Phase: Equatable {
        case idle
        case requestingPermission
        case listening
        case finishing
        case denied
        case failed(String)
    }
    
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcript = ""
    
    private let speechService: SpeechServiceProtocol
    private var recognitionTask: Task<Void, Never>?
    
    init(speechService: SpeechServiceProtocol) {
        self.speechService = speechService
    }
    
    // MARK: - Derived
    
    var isListening: Bool { phase == .listening }
    var trimmedTranscript: String { transcript.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// 저장 가능: 텍스트가 있고, 녹음/마무리 중이 아닐 때
    var canSave: Bool { !trimmedTranscript.isEmpty && phase != .listening && phase != .finishing }
    
    // MARK: - Intents
    
    func toggleListening() {
        isListening ? stop() : start()
    }
    
    func start() {
        guard recognitionTask == nil else { return }
        transcript = ""
        phase = .requestingPermission
        
        recognitionTask = Task { [weak self] in
            guard let self else { return }
            defer { self.recognitionTask = nil }
            
            let status = await self.speechService.requestAuthorization()
            guard status == .authorized else {
                self.phase = .denied
                return
            }
            
            do {
                let stream = try self.speechService.startRecognition(locale: .current)
                self.phase = .listening
                for try await event in stream {
                    switch event {
                    case .partial(let text), .final(let text):
                        self.transcript = text
                    }
                }
                self.phase = .idle
            } catch {
                self.phase = .failed(error.localizedDescription)
            }
        }
    }
    
    func stop() {
        guard phase == .listening else { return }
        phase = .finishing
        speechService.stopRecognition()
    }
    
    /// 시트가 닫힐 때 - 진행 중 세션을 끊고 마이크를 놓는다
    func cancel() {
        speechService.stopRecognition()
        recognitionTask?.cancel()
        recognitionTask = nil
        phase = .idle
    }
}
