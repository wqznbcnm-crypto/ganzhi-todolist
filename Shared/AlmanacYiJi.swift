//
//  AlmanacYiJi.swift
//  当日「宜 / 忌」事项（内置表，不联网、不推演）
//
//  数据来源：公开万年历页面（wannianrili.bmcx.com）逐日抓取，构建期一次性生成
//  Resources/AlmanacYiJi.json；键为 "yyyy-MM-dd"，值为 {"y": [...], "j": [...]}。
//  覆盖 2024-01-01 – 2029-01-31（个别月份抓取失败会缺，缺失日返回 nil，界面显示「—」）。
//
//  注意：本文件只做查表与展示，不含任何吉凶推算逻辑。
//

import Foundation

public struct YiJiDay: Equatable {
    /// 宜：万年历原文事项，按原顺序
    public let yi: [String]
    /// 忌：万年历原文事项，按原顺序
    public let ji: [String]
}

public enum AlmanacYiJi {

    /// 覆盖范围（界面提示用）
    public static let coverage = "2024.1 – 2029.1"

    /// 懒加载一次
    private static let table: [String: YiJiDay] = loadTable()

    private static func key(for date: Date) -> String {
        let c = GanzhiCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 某天的宜忌；表里没有则 nil
    public static func day(for date: Date) -> YiJiDay? {
        table[key(for: date)]
    }

    private struct RawEntry: Decodable {
        let y: [String]
        let j: [String]
    }

    private static func loadTable() -> [String: YiJiDay] {
        guard let url = Bundle.main.url(forResource: "AlmanacYiJi", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: RawEntry].self, from: data) else {
            return [:]
        }
        var result: [String: YiJiDay] = [:]
        result.reserveCapacity(raw.count)
        for (k, v) in raw {
            result[k] = YiJiDay(yi: v.y, ji: v.j)
        }
        return result
    }
}
