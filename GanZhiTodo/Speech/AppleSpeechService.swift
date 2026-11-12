//
//  AppleSpeechService.swift
//  系统中文语音识别（兜底方案，无需任何 SDK）
//  在设备已下载中文离线模型时可离线识别
//

import Foundation
import Speech
import AVFoundation

public final class AppleSpeechService: NSObject, SpeechRecognitionService {

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onVolume: ((Float) -> Void)?
    public var onError: ((String) -> Void)?
    public var onStarted: (() -> Void)?

    public static let engineName = "系统中文识别"

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastPartial = ""

    public static func isAvailable() -> Bool { true }

    public static func requestPermission(_ completion: @escaping (SpeechPermissionState) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized: completion(.authorized)
                case .denied, .restricted: completion(.denied)
                default: completion(.notDetermined)
                }
            }
        }
    }

    public func start() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        guard let recognizer, recognizer.isAvailable else {
            onError?("当前设备暂不支持中文语音识别")
            return
        }

        // 优先使用离线识别（保护隐私、无时长限制）
        if recognizer.supportsOnDeviceRecognition {
            request?.requiresOnDeviceRecognition = true
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError?("无法启动录音：\(error.localizedDescription)")
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do { try audioEngine.start() } catch {
            onError?("录音启动失败：\(error.localizedDescription)")
            return
        }

        lastPartial = ""
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.lastPartial = text
                self.onPartialResult?(text)
                if result.isFinal {
                    self.onFinalResult?(text)
                    self.stop()
                }
            }
            if let error {
                // code 203/216 等：识别中被打断或超时，属于正常结束
                self.onError?("识别结束：\(error.localizedDescription)")
            }
        }
        onStarted?()
    }

    public func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        recognizer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if !lastPartial.isEmpty { onFinalResult?(lastPartial) }
    }

    public func cancel() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        recognizer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
