//
//  AppModel.swift
//  界面状态：当前月份、选中日期、弹层路由、偏好设置
//

import SwiftUI

@MainActor
final class AppModel: ObservableObject {

    enum Route: Identifiable {
        /// 改动 9：语音录入带上下文日期 anchor
        /// （首页底部入口 = selectedDay；日/周详情 = 正在看的那天；Siri/URL 唤起 = 今天）
        case voice(anchor: Date)
        case newTodo(Date)
        case editTodo(TodoItem)
        case settings

        var id: String {
            switch self {
            case .voice(let anchor): return "voice-\(anchor.timeIntervalSince1970)"
            case .newTodo(let day): return "new-\(day.timeIntervalSince1970)"
            case .editTodo(let item): return "edit-\(item.id.uuidString)"
            case .settings: return "settings"
            }
        }
    }

    @Published var visibleMonth: Date = Date().startOfBeijingDay
    @Published var selectedDay: Date = Date().startOfBeijingDay
    @Published var route: Route?

    /// 语音引擎偏好：iflytek / apple / auto
    @Published var speechEngine: String {
        didSet { AppGroupConfig.sharedDefaults.set(speechEngine, forKey: AppGroupConfig.speechEngineKey) }
    }

    /// 23:00–23:59 的晚子时是否按次日日柱计算
    @Published var lateZiCountsAsNextDay: Bool {
        didSet { AppGroupConfig.sharedDefaults.set(lateZiCountsAsNextDay, forKey: AppGroupConfig.lateZiKey) }
    }

    /// 默认提醒（分钟），nil 表示不提醒
    @Published var defaultReminder: Int? {
        didSet {
            if let value = defaultReminder {
                AppGroupConfig.sharedDefaults.set(value, forKey: AppGroupConfig.defaultReminderKey)
            } else {
                AppGroupConfig.sharedDefaults.removeObject(forKey: AppGroupConfig.defaultReminderKey)
            }
        }
    }

    init() {
        let defaults = AppGroupConfig.sharedDefaults
        let engine = defaults.string(forKey: AppGroupConfig.speechEngineKey)
        self.speechEngine = engine ?? "auto"

        if defaults.object(forKey: AppGroupConfig.lateZiKey) == nil {
            self.lateZiCountsAsNextDay = true
        } else {
            self.lateZiCountsAsNextDay = defaults.bool(forKey: AppGroupConfig.lateZiKey)
        }

        if defaults.object(forKey: AppGroupConfig.defaultReminderKey) == nil {
            self.defaultReminder = 0
        } else {
            self.defaultReminder = defaults.integer(forKey: AppGroupConfig.defaultReminderKey)
        }
    }

    func goToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = Date().startOfBeijingDay
            selectedDay = Date().startOfBeijingDay
        }
    }

    func moveMonth(by offset: Int) {
        let cal = GanzhiCalendar.calendar
        if let next = cal.date(byAdding: .month, value: offset, to: visibleMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                visibleMonth = next.startOfBeijingDay
            }
        }
    }

    func select(_ day: Date) {
        selectedDay = day.startOfBeijingDay
    }

    /// 处理快捷指令唤醒：若存在「立即录音」标记则打开录音页
    func consumePendingVoiceFlag() {
        let defaults = AppGroupConfig.sharedDefaults
        if defaults.bool(forKey: AppGroupConfig.pendingVoiceKey) {
            defaults.set(false, forKey: AppGroupConfig.pendingVoiceKey)
            // 改动 9：Siri 唤起 anchor = 今天（不能拿上次残留的 selectedDay）
            route = .voice(anchor: Date().startOfBeijingDay)
        }
    }
}
