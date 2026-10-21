//
//  SpeechService.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//
//  [Clean Architecture - Data Layer]
//  SFSpeechRecognizer + AVAudioEngine 로 SpeechServiceProtocol 을 구현한다.
//
//  흐름:
//    startRecognition → AVAudioSession 활성화(iOS) → inputNode 에 tap 설치 →
//    오디오 버퍼를 SFSpeechAudioBufferRecognitionRequest 에 append →
//    recognitionTask 콜백이 partial/final 을 AsyncThrowingStream continuation 으로 yield.
//    stopRecognition → tap 제거 + request.endAudio() → 인식기가 마지막 final 을 보내고 끝남.
//
//  macOS 타깃에도 포함되므로 AVAudioSession(iOS 전용)은 #if os(iOS) 로 격리한다.

import Foundation
import Speech
import AVFoundation
import OSLog

@MainActor
final class SpeechService: SpeechServiceProtocol {
    
    // MARK: - State
    
    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation?
    
    private var isStopping = false
    
    nonisolated init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> SpeechAuthorizationStatus {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        switch speech {
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        case .authorized: break
        @unknown default: return .denied
        }
        
        // iOS 17 / macOS 14 공통 API. 마이크까지 허용돼야 녹음 가능
        let micGranted = await AVAudioApplication.requestRecordPermission()
        return micGranted ? .authorized : .denied
    }
    
    // MARK: - Recognition
    
    func startRecognition(locale: Locale) throws -> AsyncThrowingStream<SpeechRecognitionEvent, any Error> {
        tearDown() // 이전 세션 잔재 정리
        
        // 기기 언어가 미지원이면 시스템 기본 인식기로 폴백
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else {
            throw DozyError.speechRecognitionFailed
        }
        self.recognizer = recognizer
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        // tap 콜백은 오디오 스레드 - self 상태를 건드리지 말고 request에만 append
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return AsyncThrowingStream { continuation in
            self.continuation = continuation
            self.task = recognizer.recognitionTask(with: request) { result, error in
                // 콜백 스레드는 보장이 없다 -> 메인 액터로 올려 상태 갱신
                Task { @MainActor in
                    self.handle(result: result, error: error)
                }
            }
            continuation.onTermination = { _ in
                Task { @MainActor in self.tearDown() }
            }
        }
    }
    
    func stopRecognition() {
        guard task != nil, !isStopping else { return }
        isStopping = true
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
    }
    
    // MARK: - Private
    
    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        guard let continuation else { return }
        
        if let result {
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                continuation.yield(.final(text))
                finish(error: nil)
            } else {
                continuation.yield(.partial(text))
            }
            return
        }
        
        if let error {
            finish(error: isStopping ? nil : error)
        }
    }
    
    private func finish(error: Error?) {
        if let error {
            Logger.app.error("[Speech] 인식 실패: \(error.localizedDescription)")
            continuation?.finish(throwing: DozyError.speechRecognitionFailed)
        } else {
            continuation?.finish()
        }
        tearDown()
    }
    
    private func tearDown() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        request = nil
        continuation = nil
        isStopping = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
