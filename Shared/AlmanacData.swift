//
//  AlmanacData.swift
//  历法原始数据：十二建除 / 二十八宿值日 / 日干支冲煞 / 神煞
//
//  依据：《钦定协纪辨方书》所载规则与表
//    · 十二建除：月建（节气月支）所在之日为「建」，依次 除满平定执破危成收开闭
//    · 二十八宿值日：《协纪辨方书》「日有六十，宿有二十八，四百二十日而一周」，
//      七元甲子分别起于 虚/奎/毕/鬼/翼/氐/箕；换算成日序即「宿 = (JDN + 11) mod 28」，
//      锚点核对：2019-01-27 甲子日 = 虚、2019-02-05 = 觜、2019-02-06 = 参、2020-07-20 = 毕
//    · 冲煞：日支对冲（+6）为冲，冲干取日干 +4（天克），煞方按日支三合局
//    · 神煞：天德 / 月德 / 天赦（表见下）
//
//  ⚠️ 本文件只输出历法原始字段，**不生成宜忌等吉凶结论，也不做运势判断**。
//

import Foundation

public struct AlmanacDay: Equatable {

    /// 十二建除：建 / 除 / 满 / 平 / 定 / 执 / 破 / 危 / 成 / 收 / 开 / 闭
    public let jianchu: String
    /// 二十八宿值日（角…轸）
    public let xiu: String
    /// 宿的七政属性：木 / 金 / 土 / 日 / 月 / 火 / 水
    public let xiuElement: String
    /// 冲煞：冲（生肖 + 干支）与煞方
    public let chongText: String
    public let shaText: String
    /// 命中的神煞（天德 / 月德 / 天赦），可能为空
    public let shensha: [String]

    public var chongshaText: String { "\(chongText)\(shaText)" }
    public var shenshaText: String { shensha.isEmpty ? "无" : shensha.joined(separator: " · ") }
}

public enum Almanac {

    // MARK: 表

    /// 十二建除（序号 0 起）
    public static let jianchuNames = ["建", "除", "满", "平", "定", "执",
                                      "破", "危", "成", "收", "开", "闭"]

    /// 二十八宿（角为首）
    public static let xiuNames = ["角", "亢", "氐", "房", "心", "尾", "箕",
                                  "斗", "牛", "女", "虚", "危", "室", "壁",
                                  "奎", "娄", "胃", "昴", "毕", "觜", "参",
                                  "井", "鬼", "柳", "星", "张", "翼", "轸"]

    /// 七政属性（每七宿一轮：木金土日月火水）
    private static let qiZheng = ["木", "金", "土", "日", "月", "火", "水"]

    /// 宿值日换算常数：宿 = (JDN + 11) mod 28
    private static let xiuOffset = 11

    /// 天德：按节气月支，值可以是天干，也可以是地支
    private static let tianDe: [Int: (isStem: Bool, index: Int)] = [
        2: (true, 3),    // 寅月丁
        3: (false, 8),   // 卯月申
        4: (true, 8),    // 辰月壬
        5: (true, 7),    // 巳月辛
        6: (false, 11),  // 午月亥
        7: (true, 0),    // 未月甲
        8: (true, 9),    // 申月癸
        9: (false, 2),   // 酉月寅
        10: (true, 2),   // 戌月丙
        11: (true, 1),   // 亥月乙
        0: (false, 5),   // 子月巳
        1: (true, 6)     // 丑月庚
    ]

    /// 月德：寅午戌月丙、申子辰月壬、亥卯未月甲、巳酉丑月庚
    private static let yueDe: [Int: Int] = [
        2: 2, 6: 2, 10: 2,
        8: 8, 0: 8, 4: 8,
        11: 0, 3: 0, 7: 0,
        5: 6, 9: 6, 1: 6
    ]

    /// 天赦日：春戊寅、夏甲午、秋戊申、冬甲子
    private static let tianShe: [(months: Set<Int>, pillar: Pillar)] = [
        ([2, 3, 4], Pillar(stemIndex: 4, branchIndex: 2)),     // 戊寅
        ([5, 6, 7], Pillar(stemIndex: 0, branchIndex: 6)),     // 甲午
        ([8, 9, 10], Pillar(stemIndex: 4, branchIndex: 8)),    // 戊申
        ([11, 0, 1], Pillar(stemIndex: 0, branchIndex: 0))     // 甲子
    ]

    /// 煞方：按日支三合局
    private static func shaDirection(dayBranch: Int) -> String {
        switch dayBranch {
        case 8, 0, 4: return "煞南"      // 申子辰（水局）煞南
        case 2, 6, 10: return "煞北"     // 寅午戌（火局）煞北
        case 11, 3, 7: return "煞西"     // 亥卯未（木局）煞西
        default: return "煞东"           // 巳酉丑（金局）煞东
        }
    }

    // MARK: 计算

    /// 某一天的历法原始数据
    public static func day(for date: Date, lateZiCountsAsNextDay: Bool = true) -> AlmanacDay {
        let cal = GanzhiCalendar.calendar
        let pillars = GanzhiCalendar.shared.fourPillars(for: date, lateZiCountsAsNextDay: lateZiCountsAsNextDay)
        let dayBranch = pillars.day.branchIndex
        let monthBranch = pillars.month.branchIndex

        // 十二建除：月建当日为建
        let jianchuIndex = ((dayBranch - monthBranch) % 12 + 12) % 12

        // 二十八宿值日
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let jdn = JulianDay.dayNumber(year: comps.year ?? 2000,
                                      month: comps.month ?? 1,
                                      day: comps.day ?? 1)
        let xiuIndex = ((jdn + xiuOffset) % 28 + 28) % 28

        // 冲煞：日支对冲，冲干取日干 +4
        let chongStem = (pillars.day.stemIndex + 4) % 10
        let chongBranch = (dayBranch + 6) % 12
        let chongPillar = Pillar(stemIndex: chongStem, branchIndex: chongBranch)
        let chongText = "冲\(GanZhiText.zodiacs[chongBranch])(\(chongPillar.text))"
        let shaText = shaDirection(dayBranch: dayBranch)

        // 神煞
        var shensha: [String] = []
        if let t = tianDe[monthBranch] {
            let hit = t.isStem ? (pillars.day.stemIndex == t.index)
                               : (pillars.day.branchIndex == t.index)
            if hit { shensha.append("天德") }
        }
        if let y = yueDe[monthBranch], pillars.day.stemIndex == y {
            shensha.append("月德")
        }
        for rule in tianShe where rule.months.contains(monthBranch) && rule.pillar == pillars.day {
            shensha.append("天赦")
        }

        return AlmanacDay(jianchu: jianchuNames[jianchuIndex],
                          xiu: xiuNames[xiuIndex],
                          xiuElement: qiZheng[xiuIndex % 7],
                          chongText: chongText,
                          shaText: shaText,
                          shensha: shensha)
    }
}
