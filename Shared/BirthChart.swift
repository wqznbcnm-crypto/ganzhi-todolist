//
//  BirthChart.swift
//  我的八字：生辰四柱录入 + 大运推算（改动 6-A / 6-C）
//  直接填四柱，不做「按出生时间自动排盘」（本期不实现）。
//

import Foundation

public struct BirthChart: Equatable {
    /// 四柱；时柱允许为空（不少人不知道出生时辰）
    public var yearPillar: Pillar
    public var monthPillar: Pillar
    public var dayPillar: Pillar
    /// nil = 未填时柱
    public var hourPillar: Pillar?
    /// "男" / "女"，决定大运顺逆
    public var gender: String
    /// 出生年份（4 位，选填）：用于大运年份轴
    public var birthYear: Int?
    /// 起运月数（岁×12 + 月；nil = 未填，不显示年份与当前大运）
    public var qiyunMonths: Int?
    /// 当前所处的大运序号（0 起，0 = 第一步）。
    /// 用户可在录入页直接指定；nil = 按「出生年份 + 起运岁数」推算。
    public var currentDayunIndex: Int?

    public init(yearPillar: Pillar, monthPillar: Pillar, dayPillar: Pillar,
                hourPillar: Pillar?, gender: String, birthYear: Int?, qiyunMonths: Int?,
                currentDayunIndex: Int? = nil) {
        self.yearPillar = yearPillar
        self.monthPillar = monthPillar
        self.dayPillar = dayPillar
        self.hourPillar = hourPillar
        self.gender = gender
        self.birthYear = birthYear
        self.qiyunMonths = qiyunMonths
        self.currentDayunIndex = currentDayunIndex
    }

    /// 日柱主星显示：「元男」/「元女」
    public var dayMasterLabel: String { gender == "男" ? "元男" : "元女" }

    /// 合法性：天干与地支必须阴阳相配（奇偶一致）
    public static func isValid(stemIndex: Int, branchIndex: Int) -> Bool {
        (((stemIndex % 10) + 10) % 10) % 2 == (((branchIndex % 12) + 12) % 12) % 2
    }

    // MARK: 持久化（AppGroupConfig.sharedDefaults）

    public func save() {
        let d = AppGroupConfig.sharedDefaults
        d.set(yearPillar.text, forKey: AppGroupConfig.birthYearPillarKey)
        d.set(monthPillar.text, forKey: AppGroupConfig.birthMonthPillarKey)
        d.set(dayPillar.text, forKey: AppGroupConfig.birthDayPillarKey)
        if let h = hourPillar { d.set(h.text, forKey: AppGroupConfig.birthHourPillarKey) }
        else { d.removeObject(forKey: AppGroupConfig.birthHourPillarKey) }
        d.set(gender, forKey: AppGroupConfig.genderKey)
        if let y = birthYear { d.set(y, forKey: AppGroupConfig.birthYearKey) }
        else { d.removeObject(forKey: AppGroupConfig.birthYearKey) }
        if let q = qiyunMonths { d.set(q, forKey: AppGroupConfig.qiyunMonthsKey) }
        else { d.removeObject(forKey: AppGroupConfig.qiyunMonthsKey) }
        if let c = currentDayunIndex { d.set(c, forKey: AppGroupConfig.currentDayunKey) }
        else { d.removeObject(forKey: AppGroupConfig.currentDayunKey) }
    }

    public static func load() -> BirthChart? {
        let d = AppGroupConfig.sharedDefaults
        guard let y = pillar(d.string(forKey: AppGroupConfig.birthYearPillarKey)),
              let m = pillar(d.string(forKey: AppGroupConfig.birthMonthPillarKey)),
              let day = pillar(d.string(forKey: AppGroupConfig.birthDayPillarKey)),
              let g = d.string(forKey: AppGroupConfig.genderKey) else { return nil }
        let hour = pillar(d.string(forKey: AppGroupConfig.birthHourPillarKey))
        let birthYear = d.object(forKey: AppGroupConfig.birthYearKey) as? Int
        let qiyun = d.object(forKey: AppGroupConfig.qiyunMonthsKey) as? Int
        let dayun = d.object(forKey: AppGroupConfig.currentDayunKey) as? Int
        return BirthChart(yearPillar: y, monthPillar: m, dayPillar: day,
                          hourPillar: hour, gender: g, birthYear: birthYear, qiyunMonths: qiyun,
                          currentDayunIndex: dayun)
    }

    public static func clear() {
        let d = AppGroupConfig.sharedDefaults
        for key in [AppGroupConfig.birthYearPillarKey, AppGroupConfig.birthMonthPillarKey,
                    AppGroupConfig.birthDayPillarKey, AppGroupConfig.birthHourPillarKey,
                    AppGroupConfig.genderKey, AppGroupConfig.birthYearKey, AppGroupConfig.qiyunMonthsKey,
                    AppGroupConfig.currentDayunKey] {
            d.removeObject(forKey: key)
        }
    }

    /// "壬申" → Pillar
    public static func pillar(_ text: String?) -> Pillar? {
        guard let text, text.count == 2 else { return nil }
        let chars = Array(text)
        guard let s = GanZhiText.stems.firstIndex(of: String(chars[0])),
              let b = GanZhiText.branches.firstIndex(of: String(chars[1])) else { return nil }
        guard isValid(stemIndex: s, branchIndex: b) else { return nil }
        return Pillar(stemIndex: s, branchIndex: b)
    }
}

// MARK: - 大运（改动 6-C）

public struct DayunStep: Identifiable, Equatable {
    public let pillar: Pillar
    /// 起始年份（未填出生年份/起运岁数时为 nil）
    public let startYear: Int?
    /// 起始虚岁（同上，nil 表示不显示）
    public let startAge: Int?
    public var id: String { pillar.text + "\(startYear ?? 0)" }
}

public enum DayunCalculator {

    /// 顺逆判定：「阳男阴女顺，阴男阳女逆」
    /// 年干为阳（甲丙戊庚壬，序号偶数）且男 → 顺行；年干为阴且女 → 顺行
    public static func isForward(yearStemIndex: Int, gender: String) -> Bool {
        let yangStem = ((yearStemIndex % 10) + 10) % 10 % 2 == 0
        if yangStem && gender == "男" { return true }
        if !yangStem && gender == "女" { return true }
        return false
    }

    /// 以月柱为基准顺/逆展开 steps 步（每步管 10 年）
    public static func steps(chart: BirthChart, count: Int = 6) -> [DayunStep] {
        let forward = isForward(yearStemIndex: chart.yearPillar.stemIndex, gender: chart.gender)
        let delta = forward ? 1 : -1
        var result: [DayunStep] = []
        for i in 1...max(count, 1) {
            let index = chart.monthPillar.sexagenaryIndex + delta * i
            let pillar = Pillar(sexagenaryIndex: index)
            if let birthYear = chart.birthYear, let q = chart.qiyunMonths {
                let startAge = Int(round(Double(q) / 12.0)) + (i - 1) * 10   // 起运岁数（取整）
                result.append(DayunStep(pillar: pillar, startYear: birthYear + startAge, startAge: startAge + 1))
            } else {
                result.append(DayunStep(pillar: pillar, startYear: nil, startAge: nil))
            }
        }
        return result
    }

    /// 当前所处大运（需出生年份 + 起运岁数都填写）；nil = 未定
    public static func currentStepIndex(steps: [DayunStep], date: Date = Date()) -> Int? {
        let year = GanzhiCalendar.calendar.component(.year, from: date)
        for (i, step) in steps.enumerated() {
            guard let start = step.startYear else { continue }
            let end = start + 10
            if year >= start && year < end { return i }
        }
        return nil
    }

    /// 当前大运序号：优先用录入页手动指定的那一步，其次按出生年份 + 起运岁数推算。
    /// nil = 既没指定也算不出来（例如既没填出生年份，也没填起运岁数）。
    public static func resolvedIndex(chart: BirthChart, list: [DayunStep]? = nil,
                                     date: Date = Date()) -> Int? {
        let all = list ?? steps(chart: chart)
        if let manual = chart.currentDayunIndex, manual >= 0, manual < all.count {
            return manual
        }
        return currentStepIndex(steps: all, date: date)
    }
}
