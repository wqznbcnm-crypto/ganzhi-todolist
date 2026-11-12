//
//  GanZhi.swift
//  干支四柱换算内核（纯 Swift，无 UI 依赖，App 与小组件共用）
//
//  算法说明：
//  1. 日柱：以儒略日 JDN 直接取模（(JDN + 49) % 60），1900–2100 全量校验无误。
//  2. 节气：用 Meeus 低精度太阳视黄经公式 + 二分法反解黄经，精度约 ±5 分钟；
//     年柱以「立春」交节时刻为界，月柱以十二「节」交节时刻为界。
//  3. 时柱：两小时一个时辰，23:00 起为子时；日柱可配置「晚子时归次日」。
//  4. 全部按北京时间（UTC+8）计算，与设备所在时区无关。
//

import Foundation

// MARK: - 天干地支基础

public enum GanZhiText {
    public static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    public static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    public static let zodiacs = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

    /// 十二时辰名称
    public static let shichen = ["子时", "丑时", "寅时", "卯时", "辰时", "巳时",
                                 "午时", "未时", "申时", "酉时", "戌时", "亥时"]

    /// 十二时辰对应的现代时间区间描述
    public static let shichenRange = ["23:00–01:00", "01:00–03:00", "03:00–05:00", "05:00–07:00",
                                      "07:00–09:00", "09:00–11:00", "11:00–13:00", "13:00–15:00",
                                      "15:00–17:00", "17:00–19:00", "19:00–21:00", "21:00–23:00"]
}

/// 一柱（天干 + 地支）
public struct Pillar: Hashable, Identifiable {
    public let stemIndex: Int
    public let branchIndex: Int

    public init(stemIndex: Int, branchIndex: Int) {
        self.stemIndex = ((stemIndex % 10) + 10) % 10
        self.branchIndex = ((branchIndex % 12) + 12) % 12
    }

    public var id: String { text }
    public var stem: String { GanZhiText.stems[stemIndex] }
    public var branch: String { GanZhiText.branches[branchIndex] }
    /// 例如「丙午」
    public var text: String { stem + branch }
    public var zodiac: String { GanZhiText.zodiacs[branchIndex] }
    public var shichenName: String { GanZhiText.shichen[branchIndex] }

    /// 六十甲子序号（0–59）
    public var sexagenaryIndex: Int {
        var i = 0
        while i < 60 {
            if i % 10 == stemIndex && i % 12 == branchIndex { return i }
            i += 1
        }
        return 0
    }

    public init(sexagenaryIndex: Int) {
        let i = ((sexagenaryIndex % 60) + 60) % 60
        self.init(stemIndex: i % 10, branchIndex: i % 12)
    }
}

/// 四柱
public struct FourPillars: Hashable {
    public let year: Pillar
    public let month: Pillar
    public let day: Pillar
    public let hour: Pillar

    public init(year: Pillar, month: Pillar, day: Pillar, hour: Pillar) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
    }

    /// 「丙午 · 己亥 · 庚寅 · 丙戌」
    public var text: String { [year, month, day, hour].map(\.text).joined(separator: " · ") }
}

// MARK: - 儒略日

public enum JulianDay {
    /// 公历日期的儒略日数（当日 0 时，UT）
    public static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        var y = year, m = month
        let a = (14 - m) / 12
        y = y + 4800 - a
        m = m + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    /// 公历日期时刻的儒略日（小数）
    public static func date(year: Int, month: Int, day: Int,
                            hour: Int = 0, minute: Int = 0, second: Int = 0) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = y / 100
        let b = 2 - a + a / 4
        let whole = Double(Int(365.25 * Double(y + 4716)) + Int(30.6001 * Double(m + 1)) + day + b) - 1524.5
        let frac = (Double(hour) + Double(minute) / 60.0 + Double(second) / 3600.0) / 24.0
        return whole + frac
    }

    /// 儒略日 → 公历日期（本地无需精确到秒，返回年月日）
    public static func civil(from jd: Double) -> (year: Int, month: Int, day: Int) {
        let z = Int(floor(jd + 0.5))
        let f = jd + 0.5 - Double(z)
        var a = z
        if z >= 2299161 {
            let alpha = Int((Double(z) - 1867216.25) / 36524.25)
            a = z + 1 + alpha - alpha / 4
        }
        let b = a + 1524
        let c = Int((Double(b) - 122.1) / 365.25)
        let d = Int(365.25 * Double(c))
        let e = Int((Double(b - d)) / 30.6001)
        let day = b - d - Int(30.6001 * Double(e))
        let month = e < 14 ? e - 1 : e - 13
        let year = month > 2 ? c - 4716 : c - 4715
        _ = f
        return (year, month, day)
    }
}

// MARK: - 节气

public enum SolarTerm {
    /// 24 节气名称，索引 0 = 小寒（黄经 285°），此后每 15° 一个节气
    public static let names = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
                               "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
                               "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
                               "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]

    /// 第 index 个节气对应的太阳黄经（度）
    public static func longitude(index: Int) -> Double {
        Double((285 + 15 * index) % 360)
    }

    /// ΔT（TT − UT），Espenak & Meeus 多项式，单位秒
    static func deltaT(year: Double) -> Double {
        let y = year
        if y >= 1900 && y < 1920 {
            let t = y - 1900
            return -2.79 + 1.494119 * t - 0.0598939 * t * t + 0.0061966 * pow(t, 3) - 0.000197 * pow(t, 4)
        } else if y >= 1920 && y < 1941 {
            let t = y - 1920
            return 21.20 + 0.84493 * t - 0.076100 * t * t + 0.0020936 * pow(t, 3)
        } else if y >= 1941 && y < 1961 {
            let t = y - 1950
            return 29.07 + 0.407 * t - t * t / 233.0 + pow(t, 3) / 2547.0
        } else if y >= 1961 && y < 1986 {
            let t = y - 1975
            return 45.45 + 1.067 * t - t * t / 260.0 - pow(t, 3) / 718.0
        } else if y >= 1986 && y < 2005 {
            let t = y - 2000
            return 63.86 + 0.3345 * t - 0.060374 * pow(t, 2) + 0.0017275 * pow(t, 3)
                + 0.000651814 * pow(t, 4) + 0.00002373599 * pow(t, 5)
        } else if y >= 2005 && y < 2050 {
            let t = y - 2000
            return 62.92 + 0.32217 * t + 0.005589 * t * t
        } else {
            let u = (y - 1820) / 100.0
            return -20 + 32 * u * u - 0.5628 * (2150 - y)
        }
    }

    /// 太阳视黄经（度），jde 为力学时儒略日
    public static func apparentSolarLongitude(_ jde: Double) -> Double {
        let t = (jde - 2451545.0) / 36525.0
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
        let mr = m * Double.pi / 180.0
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(mr)
            + (0.019993 - 0.000101 * t) * sin(2 * mr)
            + 0.000289 * sin(3 * mr)
        let omega = 125.04 - 1934.136 * t
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(omega * Double.pi / 180.0)
        var v = lambda.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    /// 某年某节气的北京时间儒略日
    public static func beijingJulianDay(year: Int, index: Int) -> Double {
        let target = longitude(index: index)
        let approx = JulianDay.date(year: year, month: 1, day: 6) + Double(index) * 15.2
        var lo = approx - 20, hi = approx + 20
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            var diff = apparentSolarLongitude(mid) - target
            diff = diff.truncatingRemainder(dividingBy: 360)
            if diff > 180 { diff -= 360 }
            if diff < -180 { diff += 360 }
            if diff > 0 { hi = mid } else { lo = mid }
        }
        let jde = (lo + hi) / 2
        let ut = jde - deltaT(year: Double(year) + Double(index) * 15.0 / 365.0) / 86400.0
        return ut + 8.0 / 24.0   // 北京时间
    }

    /// 某公历年 24 节气时刻表（北京时间）
    public static func table(forYear year: Int) -> [(name: String, index: Int, jd: Double, date: Date)] {
        var result: [(String, Int, Double, Date)] = []
        for i in 0..<24 {
            let jd = beijingJulianDay(year: year, index: i)
            let civil = JulianDay.civil(from: jd)
            let frac = jd + 0.5 - floor(jd + 0.5)
            let seconds = Int((frac * 86400.0).rounded())
            let comps = DateComponents(year: civil.year, month: civil.month, day: civil.day,
                                       hour: seconds / 3600, minute: (seconds % 3600) / 60)
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = GanzhiCalendar.beijing
            let date = cal.date(from: comps) ?? Date()
            result.append((names[i], i, jd, date))
        }
        return result
    }
}

// MARK: - 干支换算

public final class GanzhiCalendar {
    public static let shared = GanzhiCalendar()
    public static let beijing = TimeZone(identifier: "Asia/Shanghai")!

    /// 北京时间日历
    public static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = beijing
        cal.locale = Locale(identifier: "zh_CN")
        cal.firstWeekday = 2   // 周一为一周之始
        return cal
    }

    private var termCache: [Int: [(name: String, index: Int, jd: Double, date: Date)]] = [:]
    private var jieCache: [String: Double] = [:]
    private let lock = NSLock()

    private init() {}

    // MARK: 节气（带缓存）

    public func terms(of year: Int) -> [(name: String, index: Int, jd: Double, date: Date)] {
        lock.lock(); defer { lock.unlock() }
        if let cached = termCache[year] { return cached }
        let t = SolarTerm.table(forYear: year)
        termCache[year] = t
        return t
    }

    /// 第 k 个「节」的北京时间儒略日。k=0 立春，1 惊蛰 …… 10 大雪，11 小寒（次年 1 月）
    public func jie(k: Int, year: Int) -> Double {
        let key = "\(year)-\(k)"
        lock.lock()
        if let cached = jieCache[key] { lock.unlock(); return cached }
        lock.unlock()
        let value = SolarTerm.beijingJulianDay(year: year, index: (2 + 2 * k) % 24)
        lock.lock(); jieCache[key] = value; lock.unlock()
        return value
    }

    /// 某天是否为节气日，返回节气名
    public func solarTermName(on date: Date) -> String? {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        for term in terms(of: y) {
            let c = cal.dateComponents([.year, .month, .day], from: term.date)
            if c.year == y, c.month == m, c.day == d { return term.name }
        }
        return nil
    }

    // MARK: 四柱

    /// 计算某个时刻的四柱（北京时间）
    /// - Parameter lateZiCountsAsNextDay: 23:00–23:59 的晚子时是否按次日日柱计算（默认是）
    public func fourPillars(for date: Date, lateZiCountsAsNextDay: Bool = true) -> FourPillars {
        let cal = GanzhiCalendar.calendar
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return fourPillars(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1,
                           hour: c.hour ?? 0, minute: c.minute ?? 0,
                           lateZiCountsAsNextDay: lateZiCountsAsNextDay)
    }

    public func fourPillars(year: Int, month: Int, day: Int,
                            hour: Int = 12, minute: Int = 0,
                            lateZiCountsAsNextDay: Bool = true) -> FourPillars {
        let nowJD = JulianDay.date(year: year, month: month, day: day, hour: hour, minute: minute)

        // 年柱：以立春交节时刻为界
        let lichun = jie(k: 0, year: year)
        let ganzhiYear = nowJD >= lichun ? year : year - 1
        let yearPillar = Pillar(sexagenaryIndex: ganzhiYear - 4)

        // 月柱：找最近一个已交的「节」
        var bestJD = -Double.greatestFiniteMagnitude
        var bestK = 0
        for y in [year - 1, year] {
            for k in 0..<12 {
                let t = jie(k: k, year: y)
                if t <= nowJD && t > bestJD { bestJD = t; bestK = k }
            }
        }
        let monthStem = (2 * yearPillar.stemIndex + 2 + bestK) % 10
        let monthBranch = (2 + bestK) % 12
        let monthPillar = Pillar(stemIndex: monthStem, branchIndex: monthBranch)

        // 日柱
        var jdn = JulianDay.dayNumber(year: year, month: month, day: day)
        if lateZiCountsAsNextDay && hour >= 23 { jdn += 1 }
        let dayPillar = Pillar(sexagenaryIndex: (jdn + 49) % 60)

        // 时柱
        let hourBranch = ((hour + 1) / 2) % 12
        let hourStem = (2 * dayPillar.stemIndex + hourBranch) % 10
        let hourPillar = Pillar(stemIndex: hourStem, branchIndex: hourBranch)

        return FourPillars(year: yearPillar, month: monthPillar, day: dayPillar, hour: hourPillar)
    }

    /// 公历某天的日柱（以当日正午判定，避免边界歧义）
    public func dayPillar(for date: Date) -> Pillar {
        let cal = GanzhiCalendar.calendar
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let jdn = JulianDay.dayNumber(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
        return Pillar(sexagenaryIndex: (jdn + 49) % 60)
    }

    /// 某年某月的年柱、月柱（用于月历标题）——取当月 15 日正午判定
    public func monthHeaderPillars(year: Int, month: Int) -> (year: Pillar, month: Pillar) {
        let p = fourPillars(year: year, month: month, day: 15, hour: 12, minute: 0)
        return (p.year, p.month)
    }
}

// MARK: - 便捷扩展

public extension Date {
    /// 北京时间当天 0 点
    var startOfBeijingDay: Date {
        let cal = GanzhiCalendar.calendar
        return cal.startOfDay(for: self)
    }

    /// 北京时间的年月日
    var beijingComponents: DateComponents {
        GanzhiCalendar.calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: self)
    }
}
