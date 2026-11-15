//
//  AppleSpeechService.swift
//  系统中文语音识别（兜底方案，无需任何 SDK）
//  在设备已下载中文离线模型时可离线识别
//
//  2026-11-15 修复（说话停顿后前文消失 / 停顿后不能继续说）：
//    原来的实现把识别器的 isFinal 当成「用户说完了」，一停顿时识别器提前收尾，
//    我们就拆掉音频、弹确认卡，后面说的全部进不来。
//    现在改成「分段累计」：isFinal 只代表这一小段结束，把这段文本累加进 committed，
//    立刻开一段新的识别继续听，直到用户点「完成」才真正 final。
//    对外仍是「onPartialResult 给累计全文、onFinalResult 恰好一次」的老契约。
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

    /// 已结束片段的累计文本
    private var committed = ""
    /// 当前片段的最新转写
    private var lastPartial = ""
    private var segmentCount = 0
    private var tapInstalled = false
    /// final 只发一次
    private var didSendFinal = false
    /// 用户已停止/取消，不再续接片段
    private var isStopping = false
    private var didCancel = false
    /// 分段上限：防止识别器反复立刻报错导致无限续接
    private let maxSegments = 30

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

    // MARK: 启动

    public func start() {
        let rec = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        guard let rec, rec.isAvailable else {
            onError?("当前设备暂不支持中文语音识别")
            return
        }
        recognizer = rec

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError?("无法启动录音：\(error.localizedDescription)")
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // request 会随分段更换，所以每次取当前值
            self?.request?.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do { try audioEngine.start() } catch {
            onError?("录音启动失败：\(error.localizedDescription)")
            return
        }

        committed = ""
        lastPartial = ""
        segmentCount = 0
        didSendFinal = false
        isStopping = false
        didCancel = false

        startSegment()
        onStarted?()
    }

    /// 开一段识别。音频引擎与 tap 一直开着，只换 request/task。
    private func startSegment() {
        guard let recognizer, !isStopping, !didCancel else { return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req
        lastPartial = ""

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            guard !self.didCancel else { return }

            if let result {
                let seg = result.bestTranscription.formattedString
                self.lastPartial = seg
                self.onPartialResult?(self.committed + seg)
                if result.isFinal {
                    // 这一小段结束（多是用户停顿），累计后继续听，不当成整场结束
                    self.committed += seg
                    self.lastPartial = ""
                    self.continueIfNeeded()
                }
                return
            }

            if error != nil {
                // 203/216 等：静音超时或被打断，把已识别部分留下，再开一段
                if !self.lastPartial.isEmpty {
                    self.committed += self.lastPartial
                    self.lastPartial = ""
                }
                self.continueIfNeeded()
            }
        }
    }

    private func continueIfNeeded() {
        guard !isStopping, !didCancel, !didSendFinal, segmentCount < maxSegments else { return }
        segmentCount += 1
        startSegment()
    }

    // MARK: 结束

    public func stop() {
        // 用户点「完成」：把累计文本作为唯一 final 交出去（空串也交，由上层判空）
        guard !didSendFinal else { return }
        didSendFinal = true
        isStopping = true
        let final = committed + lastPartial
        teardownAudio()
        onFinalResult?(final)
    }

    public func cancel() {
        didCancel = true
        isStopping = true
        teardownAudio()
    }

    /// 回收音频与识别资源，不触发任何回调
    private func teardownAudio() {
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        recognizer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
