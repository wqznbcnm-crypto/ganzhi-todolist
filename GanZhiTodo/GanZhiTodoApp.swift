//
//  GanZhiTodoApp.swift
//  应用入口
//

import SwiftUI

@main
@MainActor
struct GanZhiTodoApp: App {

    @StateObject private var store = TodoStore.shared
    @StateObject private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 初始化语音引擎（讯飞 SDK 若已集成）
        SpeechBootstrap.setup()
        NotificationScheduler.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(app)
                .tint(Theme.accent)
                // 强制中文环境：无论系统语言是什么，界面与日期控件都用中文
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .onOpenURL { url in
                    if url.host == "voice" {
                        // 改动 9：URL 唤起 anchor = 今天
                        app.route = .voice(anchor: Date().startOfBeijingDay)
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // 快捷指令唤醒后（App 可能已在后台运行），补一次标记检查
                app.consumePendingVoiceFlag()
            }
        }
    }
}
