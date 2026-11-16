//
//  PersonalNoteStore.swift
//  个人命理笔记（v7）：
//    · 以单个天干/地支为键，记录用户自己写的「宜做事项 / 忌做事项」标签
//    · 仅作个人记录，不做任何吉凶判定；首页命中时优先展示，并隐藏万年历宜忌原文
//

import Foundation

/// 单个字的笔记内容
public struct PersonalNote: Codable, Equatable {
    public var yi: [String]
    public var ji: [String]

    public init(yi: [String] = [], ji: [String] = []) {
        self.yi = yi
        self.ji = ji
    }

    public var isEmpty: Bool { yi.isEmpty && ji.isEmpty }
}

public enum NoteCatalog {
    public static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    public static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

    /// 预制标签（生活事项，用户可多选，也可自定义）
    public static let yiPresets = ["见朋友", "谈生意", "吃饭", "休息", "签约", "学习",
                                   "运动", "出行", "看病", "买东西", "理发", "打扫"]
    public static let jiPresets = ["争吵", "熬夜", "大额投资", "酒局", "远行", "动土",
                                   "借钱", "换工作", "手术", "签字", "赌气", "凌晨出门"]

    /// 免责声明（设置页小字）
    public static let disclaimer = "内容引用自传统万年历，仅作民俗文化展示，不构成任何行为建议，本App不承担相关风险。"
}

/// 与某一天命中的笔记（日柱优先，其次流月、流年）
public struct PersonalNoteHit {
    public let char: String       // 命中的那个字
    public let scope: String      // 日干 / 日支 / 流月干 / 流月支 / 流年干 / 流年支
    public let note: PersonalNote
}

public enum PersonalNoteStorage {
    public static let enabledKey = "personalNoteEnabled"
    static let entriesKey = "personalNoteEntries"

    public static func load() -> [String: PersonalNote] {
        let d = AppGroupConfig.sharedDefaults
        guard let data = d.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([String: PersonalNote].self, from: data) else {
            return [:]
        }
        return decoded
    }

    public static func save(_ entries: [String: PersonalNote]) {
        let d = AppGroupConfig.sharedDefaults
        guard let data = try? JSONEncoder().encode(entries) else { return }
        d.set(data, forKey: entriesKey)
    }

    public static var isEnabled: Bool {
        get { AppGroupConfig.sharedDefaults.bool(forKey: enabledKey) }
        set { AppGroupConfig.sharedDefaults.set(newValue, forKey: enabledKey) }
    }
}

public enum PersonalNoteMatcher {
    /// 从某一天的四柱里按 日柱 → 流月 → 流年 的顺序找第一个有内容的笔记
    public static func hit(for date: Date, lateZi: Bool,
                           entries: [String: PersonalNote]) -> PersonalNoteHit? {
        let p = GanzhiCalendar.shared.fourPillars(for: date, lateZiCountsAsNextDay: lateZi)
        let candidates: [(String, String)] = [
            (p.day.stem, "日干"), (p.day.branch, "日支"),
            (p.month.stem, "流月干"), (p.month.branch, "流月支"),
            (p.year.stem, "流年干"), (p.year.branch, "流年支")
        ]
        for (char, scope) in candidates {
            if let note = entries[char], !note.isEmpty {
                return PersonalNoteHit(char: char, scope: scope, note: note)
            }
        }
        return nil
    }
}
