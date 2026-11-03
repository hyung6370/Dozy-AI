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
            // 임의 큐에서 불린다 — @Sendable 로 메인 액터 추론을 끊는다 (Swift 6 런타임 격리 검사).
            SFSpeechRecognizer.requestAuthorization { @Sendable status in continuation.resume(returning: status) }
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
        // 입력 노드가 실제로 받는 하드웨어 포맷. 마이크 입력이 없으면(시뮬레이터에 Mac 입력 장치가 없거나
        // 세션이 아직 준비되지 않은 경우) 샘플레이트/채널이 0 으로 온다. 그 상태로 installTap 하면
        // "IsFormatSampleRateAndChannelCountValid(format)" ObjC 예외로 크래시 — Swift 로 못 잡으니 먼저 걸러낸다.
        let format = inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            Logger.app.error("[Speech] 마이크 입력 포맷 무효 (sampleRate \(format.sampleRate), channels \(format.channelCount))")
            tearDown()
            throw DozyError.microphoneUnavailable
        }
        inputNode.removeTap(onBus: 0)
        // tap 콜백은 오디오 스레드 - self 상태를 건드리지 말고 request에만 append
        // Swift 6: 블록이 Sendable 표시가 없어 메인 액터로 추론되면 오디오 스레드에서 런타임 격리 검사에 걸린다.
        // @Sendable 로 격리를 끊는다. request 는 append 만 하는 스레드 안전 API 라 unsafe 로 넘긴다.
        nonisolated(unsafe) let tapRequest = request
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            tapRequest.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            tearDown()
            throw DozyError.microphoneUnavailable
        }
        
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
