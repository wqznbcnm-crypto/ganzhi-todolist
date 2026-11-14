//
//  SharedConfig.swift
//  App 与 Widget 共用的常量与共享容器
//

import Foundation

public enum AppGroupConfig {
    /// 必须在 Xcode 的两个 target 中都勾选同一个 App Group
    public static let identifier = "group.com.workbuddy.ganzhitodo"

    /// Siri / 快捷指令唤醒后写入的「立即录音」标记
    public static let pendingVoiceKey = "pendingVoiceCapture"
    /// 晚子时是否归次日（23:00–23:59）
    public static let lateZiKey = "lateZiCountsAsNextDay"
    /// 语音引擎选择：iflytek / apple / auto
    public static let speechEngineKey = "speechEngine"
    /// 默认提醒提前量（分钟）
    public static let defaultReminderKey = "defaultReminder"
    /// 我的八字（改动 6-A）
    public static let birthYearPillarKey = "birthYearPillar"
    public static let birthMonthPillarKey = "birthMonthPillar"
    public static let birthDayPillarKey = "birthDayPillar"
    public static let birthHourPillarKey = "birthHourPillar"
    public static let genderKey = "gender"
    public static let birthYearKey = "birthYear"
    public static let qiyunMonthsKey = "qiyunMonths"
    /// 当前所处的第几步大运（0 起；用户手动指定，留空则按出生年 + 起运岁数推算）
    public static let currentDayunKey = "currentDayunIndex"
    /// 数据文件名
    public static let todosFileName = "todos.json"

    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// App 与小组件共享的数据目录
    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public static var todosURL: URL {
        containerURL.appendingPathComponent(todosFileName)
    }
}

public enum AppInfo {
    public static let displayName = "干支日历"
    /// 供快捷指令使用的 URL Scheme，需与 Info.plist 中 CFBundleURLSchemes 一致
    public static let voiceURL = URL(string: "ganzhitodo://voice")!
}
