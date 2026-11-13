//
//  VoiceTodoIntent.swift
//  Siri 快捷指令入口：喊「小记小记」打开 App 并自动开始录音
//
//  注意：Siri 只负责「唤醒打开 App」，不解析待办内容；
//  真正的语音转文字与语义解析全部在 App 内完成。
//

import Foundation
import AppIntents

struct StartVoiceTodoIntent: AppIntent {

    static var title: LocalizedStringResource = "语音记待办"
    static var description = IntentDescription("打开干支日历，并立即开始中文语音录入待办")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // 写入标记，App 激活后自动弹出录音页
        AppGroupConfig.sharedDefaults.set(true, forKey: AppGroupConfig.pendingVoiceKey)
        return .result()
    }
}

/// 注册给 Siri / 快捷指令 App 的短语
/// 注意：苹果规定每条短语必须包含 \(.applicationName)，
/// 因此纯单词（如 "Memo"）无法内置——个人唤醒词请用快捷指令 iCloud 链接分发。
struct GanZhiTodoShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartVoiceTodoIntent(),
            phrases: [
                "\(.applicationName)记一条待办",
                "\(.applicationName)语音记待办",
                "\(.applicationName)小记",
                "\(.applicationName)memo"
            ],
            shortTitle: "语音记待办",
            systemImageName: "waveform"
        )
    }
}
