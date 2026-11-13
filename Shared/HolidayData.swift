//
//  HolidayData.swift
//  中国法定节假日与调休上班日（2024–2027）
//
//  数据来源（均为国务院办公厅通知原文，中国政府网 gov.cn）：
//    2024 年：国办发明电〔2023〕7号（2023-10-25，gov.cn）
//    2025 年：国办发明电〔2024〕7号（2024-11-12，gov.cn）
//    2026 年：2025-11-04 发布（gov.cn）
//    2027 年：国办发明电〔2026〕10号（2026-11-05，gov.cn）
//
//  ⚠️ 2028 及以后年份必须按国务院办公厅当年公告追加，禁止凭推算补数据。
//     每年 11 月前后国务院会发布次年安排，届时只需在 table 末尾追加该年条目。
//

import Foundation

/// 日子类型
public enum HolidayType: String {
    /// 法定放假日（周末调休进来的日子也算，因为用户看到的是「今天不上班」）
    case holiday
    /// 调休上班日（周末但要上班，角标「班」）
    case workday
}

/// 一天的节假日信息
public struct HolidayEntry: Equatable {
    public let type: HolidayType
    /// 节日名；调休上班日沿用所属节日的名字（如「春节」）
    public let name: String
    public init(type: HolidayType, name: String) {
        self.type = type
        self.name = name
    }
}

public enum HolidayCN {

    /// 北京时间日历（固定 Gregorian + Asia/Shanghai，与干支口径一致）
    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        c.locale = Locale(identifier: "zh_CN")
        return c
    }()

    /// key 形如 "2026-02-15"
    public static func key(for date: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func info(for date: Date) -> HolidayEntry? {
        table[key(for: date)]
    }

    /// 是否法定放假日（含调休进来的工作日）
    public static func isHoliday(_ date: Date) -> Bool {
        table[key(for: date)]?.type == .holiday
    }

    /// 是否调休上班日（周末上班）
    public static func isMakeupWorkday(_ date: Date) -> Bool {
        table[key(for: date)]?.type == .workday
    }

    /// 该日所属节日名（放假或调休上班都会返回，如「春节」）
    public static func festivalName(for date: Date) -> String? {
        table[key(for: date)]?.name
    }

    // MARK: - 数据表

    public static let table: [String: HolidayEntry] = [
        // ── 2024 年 ── 国办发明电〔2023〕7号（2023-10-25，gov.cn）
        "2024-01-01": HolidayEntry(type: .holiday, name: "元旦"),
        "2024-02-04": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2024-02-10": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-11": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-12": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-13": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-14": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-15": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-16": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-17": HolidayEntry(type: .holiday, name: "春节"),
        "2024-02-18": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2024-04-04": HolidayEntry(type: .holiday, name: "清明节"),
        "2024-04-05": HolidayEntry(type: .holiday, name: "清明节"),
        "2024-04-06": HolidayEntry(type: .holiday, name: "清明节"),
        "2024-04-07": HolidayEntry(type: .workday, name: "清明节"),   // 调休上班
        "2024-04-28": HolidayEntry(type: .workday, name: "劳动节"),   // 调休上班
        "2024-05-01": HolidayEntry(type: .holiday, name: "劳动节"),
        "2024-05-02": HolidayEntry(type: .holiday, name: "劳动节"),
        "2024-05-03": HolidayEntry(type: .holiday, name: "劳动节"),
        "2024-05-04": HolidayEntry(type: .holiday, name: "劳动节"),
        "2024-05-05": HolidayEntry(type: .holiday, name: "劳动节"),
        "2024-05-11": HolidayEntry(type: .workday, name: "劳动节"),   // 调休上班
        "2024-06-10": HolidayEntry(type: .holiday, name: "端午节"),
        "2024-09-14": HolidayEntry(type: .workday, name: "中秋节"),   // 调休上班
        "2024-09-15": HolidayEntry(type: .holiday, name: "中秋节"),
        "2024-09-16": HolidayEntry(type: .holiday, name: "中秋节"),
        "2024-09-17": HolidayEntry(type: .holiday, name: "中秋节"),
        "2024-09-29": HolidayEntry(type: .workday, name: "国庆节"),   // 调休上班
        "2024-10-01": HolidayEntry(type: .holiday, name: "国庆节"),
        "2024-10-02": HolidayEntry(type: .holiday, name: "国庆节"),
        "2024-10-03": HolidayEntry(type: .holiday, name: "国庆节"),
        "2024-10-04": HolidayEntry(type: .holiday, name: "国庆节"),
        "2024-10-05": HolidayEntry(type: .holiday, name: "国庆节"),
        "2024-10-06": HolidayEntry(type: .holiday, name: "国庆节"),
        "2024-10-07": HolidayEntry(type: .holiday, name: "国庆节"),
        "2024-10-12": HolidayEntry(type: .workday, name: "国庆节"),   // 调休上班

        // ── 2025 年 ── 国办发明电〔2024〕7号（2024-11-12，gov.cn）
        "2025-01-01": HolidayEntry(type: .holiday, name: "元旦"),
        "2025-01-26": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2025-01-28": HolidayEntry(type: .holiday, name: "春节"),
        "2025-01-29": HolidayEntry(type: .holiday, name: "春节"),
        "2025-01-30": HolidayEntry(type: .holiday, name: "春节"),
        "2025-01-31": HolidayEntry(type: .holiday, name: "春节"),
        "2025-02-01": HolidayEntry(type: .holiday, name: "春节"),
        "2025-02-02": HolidayEntry(type: .holiday, name: "春节"),
        "2025-02-03": HolidayEntry(type: .holiday, name: "春节"),
        "2025-02-04": HolidayEntry(type: .holiday, name: "春节"),
        "2025-02-08": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2025-04-04": HolidayEntry(type: .holiday, name: "清明节"),
        "2025-04-05": HolidayEntry(type: .holiday, name: "清明节"),
        "2025-04-06": HolidayEntry(type: .holiday, name: "清明节"),
        "2025-04-27": HolidayEntry(type: .workday, name: "劳动节"),   // 调休上班
        "2025-05-01": HolidayEntry(type: .holiday, name: "劳动节"),
        "2025-05-02": HolidayEntry(type: .holiday, name: "劳动节"),
        "2025-05-03": HolidayEntry(type: .holiday, name: "劳动节"),
        "2025-05-04": HolidayEntry(type: .holiday, name: "劳动节"),
        "2025-05-05": HolidayEntry(type: .holiday, name: "劳动节"),
        "2025-05-31": HolidayEntry(type: .holiday, name: "端午节"),
        "2025-06-01": HolidayEntry(type: .holiday, name: "端午节"),
        "2025-06-02": HolidayEntry(type: .holiday, name: "端午节"),
        "2025-09-28": HolidayEntry(type: .workday, name: "国庆节·中秋节"),   // 调休上班
        "2025-10-01": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-02": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-03": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-04": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-05": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-06": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-07": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-08": HolidayEntry(type: .holiday, name: "国庆节·中秋节"),
        "2025-10-11": HolidayEntry(type: .workday, name: "国庆节·中秋节"),   // 调休上班

        // ── 2026 年 ── 2025-11-04 发布（gov.cn）
        "2026-01-01": HolidayEntry(type: .holiday, name: "元旦"),
        "2026-01-02": HolidayEntry(type: .holiday, name: "元旦"),
        "2026-01-03": HolidayEntry(type: .holiday, name: "元旦"),
        "2026-01-04": HolidayEntry(type: .workday, name: "元旦"),   // 调休上班
        "2026-02-14": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2026-02-15": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-16": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-17": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-18": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-19": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-20": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-21": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-22": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-23": HolidayEntry(type: .holiday, name: "春节"),
        "2026-02-28": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2026-04-04": HolidayEntry(type: .holiday, name: "清明节"),
        "2026-04-05": HolidayEntry(type: .holiday, name: "清明节"),
        "2026-04-06": HolidayEntry(type: .holiday, name: "清明节"),
        "2026-05-01": HolidayEntry(type: .holiday, name: "劳动节"),
        "2026-05-02": HolidayEntry(type: .holiday, name: "劳动节"),
        "2026-05-03": HolidayEntry(type: .holiday, name: "劳动节"),
        "2026-05-04": HolidayEntry(type: .holiday, name: "劳动节"),
        "2026-05-05": HolidayEntry(type: .holiday, name: "劳动节"),
        "2026-05-09": HolidayEntry(type: .workday, name: "劳动节"),   // 调休上班
        "2026-06-19": HolidayEntry(type: .holiday, name: "端午节"),
        "2026-06-20": HolidayEntry(type: .holiday, name: "端午节"),
        "2026-06-21": HolidayEntry(type: .holiday, name: "端午节"),
        "2026-09-20": HolidayEntry(type: .workday, name: "国庆节"),   // 调休上班
        "2026-09-25": HolidayEntry(type: .holiday, name: "中秋节"),
        "2026-09-26": HolidayEntry(type: .holiday, name: "中秋节"),
        "2026-09-27": HolidayEntry(type: .holiday, name: "中秋节"),
        "2026-10-01": HolidayEntry(type: .holiday, name: "国庆节"),
        "2026-10-02": HolidayEntry(type: .holiday, name: "国庆节"),
        "2026-10-03": HolidayEntry(type: .holiday, name: "国庆节"),
        "2026-10-04": HolidayEntry(type: .holiday, name: "国庆节"),
        "2026-10-05": HolidayEntry(type: .holiday, name: "国庆节"),
        "2026-10-06": HolidayEntry(type: .holiday, name: "国庆节"),
        "2026-10-07": HolidayEntry(type: .holiday, name: "国庆节"),
        "2026-10-10": HolidayEntry(type: .workday, name: "国庆节"),   // 调休上班

        // ── 2027 年 ── 国办发明电〔2026〕10号（2026-11-05，gov.cn）
        "2027-01-01": HolidayEntry(type: .holiday, name: "元旦"),
        "2027-01-02": HolidayEntry(type: .holiday, name: "元旦"),
        "2027-01-03": HolidayEntry(type: .holiday, name: "元旦"),
        "2027-01-31": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2027-02-05": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-06": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-07": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-08": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-09": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-10": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-11": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-12": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-13": HolidayEntry(type: .holiday, name: "春节"),
        "2027-02-14": HolidayEntry(type: .workday, name: "春节"),   // 调休上班
        "2027-04-03": HolidayEntry(type: .holiday, name: "清明节"),
        "2027-04-04": HolidayEntry(type: .holiday, name: "清明节"),
        "2027-04-05": HolidayEntry(type: .holiday, name: "清明节"),
        "2027-05-01": HolidayEntry(type: .holiday, name: "劳动节"),
        "2027-05-02": HolidayEntry(type: .holiday, name: "劳动节"),
        "2027-05-03": HolidayEntry(type: .holiday, name: "劳动节"),
        "2027-05-04": HolidayEntry(type: .holiday, name: "劳动节"),
        "2027-05-05": HolidayEntry(type: .holiday, name: "劳动节"),
        "2027-05-08": HolidayEntry(type: .workday, name: "劳动节"),   // 调休上班
        "2027-06-09": HolidayEntry(type: .holiday, name: "端午节"),
        "2027-09-15": HolidayEntry(type: .holiday, name: "中秋节"),
        "2027-09-26": HolidayEntry(type: .workday, name: "国庆节"),   // 调休上班
        "2027-10-01": HolidayEntry(type: .holiday, name: "国庆节"),
        "2027-10-02": HolidayEntry(type: .holiday, name: "国庆节"),
        "2027-10-03": HolidayEntry(type: .holiday, name: "国庆节"),
        "2027-10-04": HolidayEntry(type: .holiday, name: "国庆节"),
        "2027-10-05": HolidayEntry(type: .holiday, name: "国庆节"),
        "2027-10-06": HolidayEntry(type: .holiday, name: "国庆节"),
        "2027-10-07": HolidayEntry(type: .holiday, name: "国庆节"),
        "2027-10-09": HolidayEntry(type: .workday, name: "国庆节"),   // 调休上班

    ]
}
