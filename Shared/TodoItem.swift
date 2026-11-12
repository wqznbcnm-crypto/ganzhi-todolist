//
//  TodoItem.swift
//  待办数据模型（本地存储，App 与小组件共享）
//

import Foundation

public struct TodoItem: Codable, Identifiable, Hashable {
    public var id: UUID
    /// 待办内容
    public var title: String
    /// 备注（可选）
    public var note: String
    /// 事件时间；nil 表示「当天但不指时刻」
    public var dueDate: Date?
    /// 是否已完成
    public var isDone: Bool
    public var createdAt: Date
    public var completedAt: Date?
    /// 提前提醒的分钟数（0 = 准时提醒）；为空表示不提醒
    public var reminderOffsets: [Int]
    /// 是否需要整天标记（无具体时刻时按当天 09:00 计算提醒）
    public var allDay: Bool

    public init(id: UUID = UUID(),
                title: String,
                note: String = "",
                dueDate: Date? = nil,
                isDone: Bool = false,
                createdAt: Date = Date(),
                completedAt: Date? = nil,
                reminderOffsets: [Int] = [],
                allDay: Bool = false) {
        self.id = id
        self.title = title
        self.note = note
        self.dueDate = dueDate
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reminderOffsets = reminderOffsets
        self.allDay = allDay
    }

    /// 用于日历归日的日期
    public var calendarDay: Date {
        (dueDate ?? createdAt).startOfBeijingDay
    }

    /// 显示用时间文本，例如「15:30」「全天」
    public var timeText: String {
        guard let due = dueDate else { return "全天" }
        if allDay { return "全天" }
        let comps = GanzhiCalendar.calendar.dateComponents([.hour, .minute], from: due)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}

// MARK: - 提醒预设

public struct ReminderPreset: Identifiable, Hashable {
    public let minutes: Int
    public let title: String
    public var id: Int { minutes }

    public static let all: [ReminderPreset] = [
        .init(minutes: 0, title: "准时"),
        .init(minutes: 5, title: "提前 5 分钟"),
        .init(minutes: 15, title: "提前 15 分钟"),
        .init(minutes: 30, title: "提前 30 分钟"),
        .init(minutes: 60, title: "提前 1 小时"),
        .init(minutes: 180, title: "提前 3 小时"),
        .init(minutes: 720, title: "提前 12 小时"),
        .init(minutes: 1440, title: "提前 1 天"),
        .init(minutes: 2880, title: "提前 2 天"),
        .init(minutes: 4320, title: "提前 3 天"),
        .init(minutes: 10080, title: "提前 1 周"),
        .init(minutes: 43200, title: "提前 30 天")
    ]

    public static func title(for minutes: Int) -> String {
        if let preset = all.first(where: { $0.minutes == minutes }) { return preset.title }
        if minutes % 1440 == 0 { return "提前 \(minutes / 1440) 天" }
        if minutes % 60 == 0 { return "提前 \(minutes / 60) 小时" }
        return "提前 \(minutes) 分钟"
    }
}
