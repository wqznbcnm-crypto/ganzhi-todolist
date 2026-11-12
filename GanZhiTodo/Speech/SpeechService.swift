//
//  SpeechService.swift
//  语音识别统一接口：优先科大讯飞 SDK，未集成时自动退回系统中文语音识别
//

import Foundation

public enum SpeechPermissionState {
    case authorized
    case denied
    case notDetermined
}

/// 识别引擎（App 内选择）
public enum SpeechEngine: String {
    case auto = "auto"
    case iflytek = "iflytek"
    case apple = "apple"
}

public protocol SpeechRecognitionService: AnyObject {
    /// 实时部分结果
    var onPartialResult: ((String) -> Void)? { get set }
    /// 最终结果（停止或静音结束）
    var onFinalResult: ((String) -> Void)? { get set }
    /// 音量（0–100，用于波形动画，可选）
    var onVolume: ((Float) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    /// 已授权并成功开始
    var onStarted: (() -> Void)? { get set }

    static var engineName: String { get }
    static func isAvailable() -> Bool
    static func requestPermission(_ completion: @escaping (SpeechPermissionState) -> Void)
    func start()
    func stop()
    func cancel()
}

/// 引擎工厂：根据偏好与可用性选择实现
public enum SpeechServiceFactory {
    public static func make(preference: String) -> SpeechRecognitionService {
        let pref = SpeechEngine(rawValue: preference) ?? .auto

        switch pref {
        case .iflytek:
            if IFlytekSpeechService.isAvailable() {
                return IFlytekSpeechService()
            }
            // 用户选了讯飞但未集成 SDK，退回系统识别
            return AppleSpeechService()
        case .apple:
            return AppleSpeechService()
        case .auto:
            if IFlytekSpeechService.isAvailable() {
                return IFlytekSpeechService()
            }
            return AppleSpeechService()
        }
    }

    public static func iflytekAvailable() -> Bool {
        IFlytekSpeechService.isAvailable()
    }

    public static var currentEngineName: String {
        iflytekAvailable() ? "科大讯飞" : "系统中文识别"
    }
}

/// App 启动时调用：初始化讯飞 SDK（若已集成）
public enum SpeechBootstrap {
    public static func setup() {
        IFlytekSpeechService.configureIfNeeded()
    }
}
