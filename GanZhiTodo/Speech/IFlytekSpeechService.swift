//
//  IFlytekSpeechService.swift
//  科大讯飞语音识别（需手动集成 iflyMSC.framework 后生效）
//
//  集成步骤见 README：把 iflyMSC.framework 拖入工程，并在下面填入你的 AppID。
//  未集成 SDK 时，本文件会编译成空实现，App 自动改用系统中文识别。
//

import Foundation
import AVFoundation

#if canImport(iflyMSC)
import iflyMSC

public enum IFlytekConfig {
    /// TODO: 替换为你在讯飞开放平台申请的 AppID
    public static let appID = "请替换为你的讯飞AppID"
}

public final class IFlytekSpeechService: NSObject, SpeechRecognitionService {

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onVolume: ((Float) -> Void)?
    public var onError: ((String) -> Void)?
    public var onStarted: (() -> Void)?

    public static let engineName = "科大讯飞"

    private var recognizer: IFlySpeechRecognizer?
    private var accumulated = ""
    private var started = false

    public static func isAvailable() -> Bool { true }

    public static func configureIfNeeded() {
        guard !IFlytekConfig.appID.hasPrefix("请替换") else { return }
        IFlySpeechUtility.createUtility("appid=\(IFlytekConfig.appID)")
    }

    public static func requestPermission(_ completion: @escaping (SpeechPermissionState) -> Void) {
        // 讯飞 SDK 使用系统麦克风权限，这里沿用系统录音授权
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted ? .authorized : .denied)
            }
        }
    }

    public func start() {
        guard IFlytekConfig.appID.hasPrefix("请替换") == false else {
            onError?("尚未配置讯飞 AppID，已改用系统识别")
            return
        }

        let rec = IFlySpeechRecognizer.sharedInstance() ?? IFlySpeechRecognizer()
        rec.delegate = self
        rec.setParameter("", forKey: "params")

        // 听写（iat）、普通话、麦克风输入
        rec.setParameter("iat", forKey: "domain")
        rec.setParameter("zh_cn", forKey: "language")
        rec.setParameter("mandarin", forKey: "accent")
        rec.setParameter("16000", forKey: "sample_rate")
        rec.setParameter("0", forKey: "audio_source")     // 0 = 麦克风
        rec.setParameter("3000", forKey: "vad_eos")       // 静音 3 秒自动结束
        rec.setParameter("10000", forKey: "vad_bos")      // 10 秒未开口结束
        rec.setParameter("plain", forKey: "result_type")  // 纯文本结果

        accumulated = ""
        started = false
        recognizer = rec

        DispatchQueue.main.async { [weak self] in
            let ok = rec.startListening()
            if !ok {
                self?.onError?("讯飞识别启动失败，已改用系统识别")
            }
        }
    }

    public func stop() {
        recognizer?.stopListening()
        if !accumulated.isEmpty {
            onFinalResult?(accumulated)
        }
        accumulated = ""
    }

    public func cancel() {
        recognizer?.cancel()
        accumulated = ""
    }
}

extension IFlytekSpeechService: IFlySpeechRecognizerDelegate {

    public func onBeginOfSpeech() {
        started = true
        onStarted?()
    }

    public func onEndOfSpeech() {
        // 静音结束，等待 onResults 的 isLast
    }

    public func onVolumeChanged(_ volume: Int32) {
        onVolume?(Float(volume))
    }

    public func onCancel() {}

    public func onError(_ errorCode: IFlySpeechError!) {
        let desc = errorCode?.errorDesc ?? "未知错误"
        onError?("识别出错：\(desc)")
    }

    public func onResults(_ results: [Any]!, isLast: Bool) {
        var text = ""
        for case let dict as [String: Any] in results ?? [] {
            if let ws = dict["ws"] as? [[String: Any]] {
                for w in ws {
                    if let cw = w["cw"] as? [[String: Any]], let first = cw.first, let word = first["w"] as? String {
                        text += word
                    }
                }
            }
        }
        accumulated += text
        onPartialResult?(accumulated)
        if isLast {
            onFinalResult?(accumulated)
            accumulated = ""
        }
    }
}

#else

/// SDK 未集成时的占位实现
public enum IFlytekConfig {
    public static let appID = ""
}

public final class IFlytekSpeechService: NSObject, SpeechRecognitionService {

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onVolume: ((Float) -> Void)?
    public var onError: ((String) -> Void)?
    public var onStarted: (() -> Void)?

    public static let engineName = "科大讯飞"

    public static func isAvailable() -> Bool { false }
    public static func configureIfNeeded() {}

    public static func requestPermission(_ completion: @escaping (SpeechPermissionState) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted ? .authorized : .denied)
            }
        }
    }

    public func start() {}
    public func stop() {}
    public func cancel() {}
}

#endif
